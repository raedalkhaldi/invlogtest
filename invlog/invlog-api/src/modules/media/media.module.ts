import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { BullModule } from '@nestjs/bullmq';
import { PostMedia } from '../posts/entities/post.entity';
import { MediaController } from './media.controller';
import { MediaService } from './media.service';
import { StorageService } from './storage.service';
import { MediaProcessor } from './media.processor';

@Module({
  imports: [
    TypeOrmModule.forFeature([PostMedia]),
    BullModule.registerQueue({ name: 'media-processing' }),
  ],
  controllers: [MediaController],
  providers: [MediaService, StorageService, MediaProcessor],
  exports: [MediaService, StorageService],
})
export class MediaModule {}
