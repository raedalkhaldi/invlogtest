import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, In, IsNull } from 'typeorm';
import { InjectQueue } from '@nestjs/bullmq';
import type { Queue } from 'bullmq';
import { randomUUID } from 'node:crypto';
import { PostMedia } from '../posts/entities/post.entity';
import { StorageService } from './storage.service';
import type { PresignUploadDto } from './dto/presign-upload.dto';
import type { CompleteUploadDto } from './dto/complete-upload.dto';

@Injectable()
export class MediaService {
  constructor(
    private readonly storageService: StorageService,
    @InjectRepository(PostMedia)
    private readonly mediaRepo: Repository<PostMedia>,
    @InjectQueue('media-processing')
    private readonly mediaQueue: Queue,
  ) {}

  async presignUpload(
    uploaderId: string,
    dto: PresignUploadDto,
  ): Promise<{ mediaId: string; uploadUrl: string; publicUrl: string }> {
    const s3Key = `uploads/${uploaderId}/${randomUUID()}-${dto.fileName}`;

    const uploadUrl = await this.storageService.generatePresignedPutUrl(
      s3Key,
      dto.contentType,
      dto.fileSize,
    );

    const publicUrl = this.storageService.getPublicUrl(s3Key);

    const mediaType = dto.contentType.startsWith('video/') ? 'video' : 'image';

    const record = this.mediaRepo.create({
      uploaderId,
      postId: null,
      mediaType,
      url: publicUrl,
      processingStatus: 'pending',
      sortOrder: 0,
    });

    const saved = await this.mediaRepo.save(record);

    return {
      mediaId: saved.id,
      uploadUrl,
      publicUrl: saved.url,
    };
  }

  async completeUpload(
    mediaId: string,
    userId: string,
    dto: CompleteUploadDto,
  ): Promise<PostMedia> {
    const media = await this.mediaRepo.findOne({ where: { id: mediaId } });
    if (!media) {
      throw new NotFoundException('Media not found');
    }

    if (media.uploaderId !== userId) {
      throw new ForbiddenException('You can only complete your own uploads');
    }

    // Extract s3Key from the public URL
    const mediaBaseUrl = this.storageService.getPublicUrl('');
    const s3Key = media.url.replace(mediaBaseUrl, '');

    // Verify the file was actually uploaded to S3
    const exists = await this.storageService.headObject(s3Key);
    if (!exists) {
      throw new BadRequestException('File not uploaded');
    }

    if (dto.width) media.width = dto.width;
    if (dto.height) media.height = dto.height;
    media.processingStatus = 'processing';

    const updated = await this.mediaRepo.save(media);

    await this.mediaQueue.add('process', { mediaId, s3Key });

    return updated;
  }

  async findById(id: string): Promise<PostMedia> {
    const media = await this.mediaRepo.findOne({ where: { id } });
    if (!media) {
      throw new NotFoundException('Media not found');
    }
    return media;
  }

  async findByIds(ids: string[], uploaderId: string): Promise<PostMedia[]> {
    if (!ids.length) return [];
    return this.mediaRepo.find({
      where: {
        id: In(ids),
        uploaderId,
        postId: IsNull(),
      },
    });
  }
}
