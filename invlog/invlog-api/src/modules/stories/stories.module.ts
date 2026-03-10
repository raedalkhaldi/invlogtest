import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Story, StoryView } from './entities/story.entity';
import { PostMedia } from '../posts/entities/post.entity';
import { User } from '../users/entities/user.entity';
import { StoriesService } from './stories.service';
import { StoriesController } from './stories.controller';
import { FollowsModule } from '../follows/follows.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([Story, StoryView, PostMedia, User]),
    FollowsModule,
  ],
  controllers: [StoriesController],
  providers: [StoriesService],
  exports: [StoriesService],
})
export class StoriesModule {}
