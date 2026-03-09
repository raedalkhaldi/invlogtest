import { Processor, WorkerHost } from '@nestjs/bullmq';
import { Job } from 'bullmq';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import sharp from 'sharp';
import { encode } from 'blurhash';
import { StorageService } from './storage.service';
import { PostMedia } from '../posts/entities/post.entity';
import { Logger } from '@nestjs/common';

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
      // 1. Download original
      const buffer = await this.storageService.getObjectBuffer(s3Key);

      // 2. Process with sharp - auto-rotate strips EXIF orientation, .rotate() strips all EXIF
      const image = sharp(buffer).rotate();
      const metadata = await image.metadata();
      const width = metadata.width ?? 0;
      const height = metadata.height ?? 0;

      // 3. Generate 3 sizes (original clean max 2048, medium 800, thumb 400)
      const [originalBuf, mediumBuf, thumbBuf] = await Promise.all([
        image
          .clone()
          .resize(2048, 2048, { fit: 'inside', withoutEnlargement: true })
          .webp({ quality: 85 })
          .toBuffer(),
        image
          .clone()
          .resize(800, 800, { fit: 'inside', withoutEnlargement: true })
          .webp({ quality: 80 })
          .toBuffer(),
        image
          .clone()
          .resize(400, 400, { fit: 'inside', withoutEnlargement: true })
          .webp({ quality: 75 })
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

      this.logger.log(`Media ${mediaId} processed successfully`);
    } catch (error) {
      this.logger.error(`Failed to process media ${mediaId}`, error);
      await this.mediaRepo.update(mediaId, { processingStatus: 'failed' });
      throw error;
    }
  }
}
