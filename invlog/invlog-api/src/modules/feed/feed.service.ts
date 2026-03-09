import { Injectable } from '@nestjs/common';
import { FollowsService } from '../follows/follows.service';
import { PostsService } from '../posts/posts.service';
import type { Post } from '../posts/entities/post.entity';

@Injectable()
export class FeedService {
  constructor(
    private readonly followsService: FollowsService,
    private readonly postsService: PostsService,
  ) {}

  async getFeed(
    userId: string,
    cursor?: string,
    limit: number = 20,
  ): Promise<{ data: Post[]; nextCursor: string | null }> {
    // Get all user IDs that the current user follows
    const followedUserIds =
      await this.followsService.getFollowedUserIds(userId);

    // Include the user's own posts in the feed
    const authorIds = [...followedUserIds, userId];

    return this.postsService.findByAuthorIds(authorIds, cursor, limit);
  }

  async getExploreFeed(
    userId: string,
    cursor?: string,
    limit: number = 20,
  ): Promise<{ data: Post[]; nextCursor: string | null }> {
    return this.postsService.findPublicPosts(userId, cursor, limit);
  }
}
