import { Processor, WorkerHost } from '@nestjs/bullmq';
import { Job } from 'bullmq';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import sharp from 'sharp';
import { encode } from 'blurhash';
import { StorageService } from './storage.service';
import { PostMedia } from '../posts/entities/post.entity';
import { Logger } from '@nestjs/common';
import { tmpdir } from 'os';
import { join } from 'path';
import { writeFile, unlink, readFile } from 'fs/promises';
import { randomUUID } from 'crypto';

// eslint-disable-next-line @typescript-eslint/no-require-imports
const ffmpegPath = require('@ffmpeg-installer/ffmpeg').path;
// eslint-disable-next-line @typescript-eslint/no-require-imports
const ffmpeg = require('fluent-ffmpeg');
ffmpeg.setFfmpegPath(ffmpegPath);

@Processor('media-processing')
export class MediaProcessor extends WorkerHost {
  private readonly logger = new Logger(MediaProcessor.name);

  constructor(
    private readonly storageService: StorageService,
    @InjectRepository(PostMedia)
    private readonly mediaRepo: Repository<PostMedia>,
  ) {
    super();
  }

  async process(job: Job<{ mediaId: string; s3Key: string }>): Promise<void> {
    const { mediaId, s3Key } = job.data;
    this.logger.log(`Processing media ${mediaId}`);

    try {
      const media = await this.mediaRepo.findOne({ where: { id: mediaId } });
      if (!media) {
        throw new Error(`Media ${mediaId} not found`);
      }

      if (media.mediaType === 'video') {
        await this.processVideo(mediaId, s3Key);
      } else {
        await this.processImage(mediaId, s3Key);
      }

      this.logger.log(`Media ${mediaId} processed successfully`);
    } catch (error) {
      this.logger.error(`Failed to process media ${mediaId}`, error);
      await this.mediaRepo.update(mediaId, { processingStatus: 'failed' });
      throw error;
    }
  }

  private async processImage(
    mediaId: string,
    s3Key: string,
  ): Promise<void> {
    // 1. Download original
    const buffer = await this.storageService.getObjectBuffer(s3Key);

    // 2. Process with sharp - auto-rotate strips EXIF orientation, .rotate() strips all EXIF
    const image = sharp(buffer).rotate();
    const metadata = await image.metadata();
    const width = metadata.width ?? 0;
    const height = metadata.height ?? 0;

    // 3. Generate 3 sizes (original clean max 2048, medium 1080, thumb 600)
    const [originalBuf, mediumBuf, thumbBuf] = await Promise.all([
      image
        .clone()
        .resize(2048, 2048, { fit: 'inside', withoutEnlargement: true })
        .webp({ quality: 92 })
        .toBuffer(),
      image
        .clone()
        .resize(1080, 1080, { fit: 'inside', withoutEnlargement: true })
        .webp({ quality: 85 })
        .toBuffer(),
      image
        .clone()
        .resize(600, 600, { fit: 'inside', withoutEnlargement: true })
        .webp({ quality: 80 })
        .toBuffer(),
    ]);

    // 4. Generate blurhash from small version
    const { data: rawPixels, info } = await image
      .clone()
      .resize(32, 32, { fit: 'inside' })
      .ensureAlpha()
      .raw()
      .toBuffer({ resolveWithObject: true });
    const blurhash = encode(
      new Uint8ClampedArray(rawPixels),
      info.width,
      info.height,
      4,
      3,
    );

    // 5. Upload processed versions
    const prefix = `processed/${mediaId}`;
    await Promise.all([
      this.storageService.putObject(
        `${prefix}/original.webp`,
        originalBuf,
        'image/webp',
      ),
      this.storageService.putObject(
        `${prefix}/medium.webp`,
        mediumBuf,
        'image/webp',
      ),
      this.storageService.putObject(
        `${prefix}/thumb.webp`,
        thumbBuf,
        'image/webp',
      ),
    ]);

    // 6. Get processed dimensions
    const processedMeta = await sharp(originalBuf).metadata();

    // 7. Update PostMedia record
    await this.mediaRepo.update(mediaId, {
      url: this.storageService.getPublicUrl(`${prefix}/original.webp`),
      mediumUrl: this.storageService.getPublicUrl(`${prefix}/medium.webp`),
      thumbnailUrl: this.storageService.getPublicUrl(`${prefix}/thumb.webp`),
      width: processedMeta.width ?? width,
      height: processedMeta.height ?? height,
      blurhash,
      processingStatus: 'ready',
    });

    // 8. Delete original upload
    await this.storageService.deleteObject(s3Key);
  }

  private async processVideo(
    mediaId: string,
    s3Key: string,
  ): Promise<void> {
    const buffer = await this.storageService.getObjectBuffer(s3Key);
    const tmpId = randomUUID();
    const inputPath = join(tmpdir(), `invlog-input-${tmpId}.mp4`);
    const outputPath = join(tmpdir(), `invlog-output-${tmpId}.mp4`);
    const thumbPath = join(tmpdir(), `invlog-thumb-${tmpId}.png`);

    try {
      await writeFile(inputPath, buffer);

      // 1. Probe video for duration and dimensions
      const probe = await this.probeVideo(inputPath);
      const duration = Math.min(probe.duration, 10); // Cap at 10 seconds
      const videoWidth = probe.width;
      const videoHeight = probe.height;

      // 2. Transcode to compressed MP4 (H.264, max 1080p, 30fps, trimmed to 10s)
      await this.transcodeVideo(inputPath, outputPath, duration);

      // 3. Extract first frame as thumbnail
      await this.extractThumbnail(inputPath, thumbPath);

      // 4. Generate thumbnail variants with Sharp
      const thumbBuffer = await readFile(thumbPath);
      const thumbImage = sharp(thumbBuffer);

      const [mediumBuf, smallBuf] = await Promise.all([
        thumbImage
          .clone()
          .resize(1080, 1080, { fit: 'inside', withoutEnlargement: true })
          .webp({ quality: 85 })
          .toBuffer(),
        thumbImage
          .clone()
          .resize(600, 600, { fit: 'inside', withoutEnlargement: true })
          .webp({ quality: 80 })
          .toBuffer(),
      ]);

      // 5. Generate blurhash from thumbnail
      const { data: rawPixels, info } = await thumbImage
        .clone()
        .resize(32, 32, { fit: 'inside' })
        .ensureAlpha()
        .raw()
        .toBuffer({ resolveWithObject: true });
      const blurhash = encode(
        new Uint8ClampedArray(rawPixels),
        info.width,
        info.height,
        4,
        3,
      );

      // 6. Read transcoded video
      const videoBuf = await readFile(outputPath);

      // 7. Upload all processed files
      const prefix = `processed/${mediaId}`;
      await Promise.all([
        this.storageService.putObject(
          `${prefix}/video.mp4`,
          videoBuf,
          'video/mp4',
        ),
        this.storageService.putObject(
          `${prefix}/medium.webp`,
          mediumBuf,
          'image/webp',
        ),
        this.storageService.putObject(
          `${prefix}/thumb.webp`,
          smallBuf,
          'image/webp',
        ),
      ]);

      // 8. Update PostMedia record
      await this.mediaRepo.update(mediaId, {
        url: this.storageService.getPublicUrl(`${prefix}/video.mp4`),
        mediumUrl: this.storageService.getPublicUrl(`${prefix}/medium.webp`),
        thumbnailUrl: this.storageService.getPublicUrl(`${prefix}/thumb.webp`),
        width: videoWidth,
        height: videoHeight,
        durationSecs: Math.round(duration * 100) / 100,
        blurhash,
        processingStatus: 'ready',
      });

      // 9. Delete original upload
      await this.storageService.deleteObject(s3Key);
    } finally {
      // Clean up temp files
      await unlink(inputPath).catch(() => {});
      await unlink(outputPath).catch(() => {});
      await unlink(thumbPath).catch(() => {});
    }
  }

  private probeVideo(
    inputPath: string,
  ): Promise<{ duration: number; width: number; height: number }> {
    return new Promise((resolve, reject) => {
      ffmpeg.ffprobe(inputPath, (err: Error, data: any) => {
        if (err) return reject(err);
        const videoStream = data.streams?.find(
          (s: any) => s.codec_type === 'video',
        );
        resolve({
          duration: parseFloat(data.format?.duration ?? '0'),
          width: videoStream?.width ?? 0,
          height: videoStream?.height ?? 0,
        });
      });
    });
  }

  private transcodeVideo(
    inputPath: string,
    outputPath: string,
    maxDuration: number,
  ): Promise<void> {
    return new Promise((resolve, reject) => {
      ffmpeg(inputPath)
        .duration(maxDuration)
        .videoCodec('libx264')
        .size('?x1080') // Scale to max 1080p height, maintain aspect ratio
        .autopad()
        .fps(30)
        .videoBitrate('4000k')
        .audioCodec('aac')
        .audioBitrate('128k')
        .outputOptions([
          '-preset fast',
          '-movflags +faststart', // Enable progressive playback
          '-pix_fmt yuv420p', // Maximum compatibility
        ])
        .on('end', () => resolve())
        .on('error', (err: Error) => reject(err))
        .save(outputPath);
    });
  }

  private extractThumbnail(
    inputPath: string,
    outputPath: string,
  ): Promise<void> {
    return new Promise((resolve, reject) => {
      ffmpeg(inputPath)
        .screenshots({
          count: 1,
          timemarks: ['0.5'], // 0.5 seconds in
          filename: outputPath.split('/').pop(),
          folder: outputPath.substring(0, outputPath.lastIndexOf('/')),
          size: '1080x?',
        })
        .on('end', () => resolve())
        .on('error', (err: Error) => reject(err));
    });
  }
}
