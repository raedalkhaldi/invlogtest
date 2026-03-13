import { Module } from '@nestjs/common';
import { FeedService } from './feed.service';
import { FeedController } from './feed.controller';
import { FollowsModule } from '../follows/follows.module';
import { PostsModule } from '../posts/posts.module';
import { BlocksModule } from '../blocks/blocks.module';

@Module({
  imports: [FollowsModule, PostsModule, BlocksModule],
  controllers: [FeedController],
  providers: [FeedService],
})
export class FeedModule {}
