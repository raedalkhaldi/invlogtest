import { Injectable, Inject } from '@nestjs/common';
import { CACHE_MANAGER } from '@nestjs/cache-manager';
import type { Cache } from 'cache-manager';
import { FollowsService } from '../follows/follows.service';
import { PostsService } from '../posts/posts.service';
import { BlocksService } from '../blocks/blocks.service';
import type { Post } from '../posts/entities/post.entity';

@Injectable()
export class FeedService {
  constructor(
    private readonly followsService: FollowsService,
    private readonly postsService: PostsService,
    private readonly blocksService: BlocksService,
    @Inject(CACHE_MANAGER) private readonly cache: Cache,
  ) {}

  async getFeed(
    userId: string,
    cursor?: string,
    limit: number = 20,
  ): Promise<{ data: Post[]; nextCursor: string | null }> {
    // Cache followed user IDs for 2 minutes (avoid re-fetching on every scroll)
    const cacheKey = `feed:follows:${userId}`;
    let followedUserIds = await this.cache.get<string[]>(cacheKey);

    if (!followedUserIds) {
      followedUserIds = await this.followsService.getFollowedUserIds(userId);
      await this.cache.set(cacheKey, followedUserIds, 120000); // 2 min
    }

    // Exclude blocked users
    const blockedIds = await this.blocksService.getAllBlockRelatedIds(userId);
    const filteredFollowed = followedUserIds.filter((id) => !blockedIds.includes(id));

    // Include the user's own posts in the feed
    const authorIds = [...filteredFollowed, userId];

    return this.postsService.findByAuthorIds(authorIds, cursor, limit, userId);
  }

  async getExploreFeed(
    userId: string,
    cursor?: string,
    limit: number = 20,
  ): Promise<{ data: Post[]; nextCursor: string | null }> {
    return this.postsService.findPublicPosts(userId, cursor, limit);
  }

  /** Call this when a user follows/unfollows someone to invalidate their feed cache */
  async invalidateFeedCache(userId: string): Promise<void> {
    await this.cache.del(`feed:follows:${userId}`);
  }
}
