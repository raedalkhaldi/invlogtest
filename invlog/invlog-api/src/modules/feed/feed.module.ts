import { Module } from '@nestjs/common';
import { FeedService } from './feed.service';
import { FeedController } from './feed.controller';
import { FollowsModule } from '../follows/follows.module';
import { PostsModule } from '../posts/posts.module';

@Module({
  imports: [FollowsModule, PostsModule],
  controllers: [FeedController],
  providers: [FeedService],
})
export class FeedModule {}
