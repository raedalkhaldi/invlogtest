import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from '../users/entities/user.entity';
import { Restaurant } from '../restaurants/entities/restaurant.entity';
import { Post } from '../posts/entities/post.entity';
import { SearchQueryDto } from './dto/search-query.dto';

@Injectable()
export class SearchService {
  constructor(
    @InjectRepository(User)
    private readonly userRepo: Repository<User>,
    @InjectRepository(Restaurant)
    private readonly restaurantRepo: Repository<Restaurant>,
    @InjectRepository(Post)
    private readonly postRepo: Repository<Post>,
  ) {}

  async search(
    dto: SearchQueryDto,
    currentUserId: string,
  ): Promise<{ restaurants: Restaurant[]; users: User[]; posts: any[] }> {
    const hasQuery = dto.q && dto.q.trim().length > 0;
    const pattern = hasQuery ? `%${dto.q}%` : null;
    const type = dto.type ?? null;
    const limit = dto.limit ?? (type ? 20 : 5);

    // If a specific type is requested, only query that type
    if (type === 'restaurants') {
      const restaurants = await this.searchRestaurants(pattern, limit);
      return { restaurants, users: [], posts: [] };
    }
    if (type === 'people') {
      const users = await this.searchUsers(pattern, limit);
      return { restaurants: [], users, posts: [] };
    }
    if (type === 'posts') {
      const posts = await this.searchPosts(pattern, limit);
      return { restaurants: [], users: [], posts };
    }

    // No type filter — search all in parallel
    const [restaurants, users, posts] = await Promise.all([
      this.searchRestaurants(pattern, limit),
      this.searchUsers(pattern, limit),
      this.searchPosts(pattern, limit),
    ]);

    return { restaurants, users, posts };
  }

  private async searchUsers(pattern: string | null, limit: number): Promise<User[]> {
    const qb = this.userRepo
      .createQueryBuilder('u')
      .select([
        'u.id',
        'u.username',
        'u.displayName',
        'u.bio',
        'u.avatarUrl',
        'u.coverUrl',
        'u.isVerified',
        'u.isPrivate',
        'u.followerCount',
        'u.followingCount',
        'u.postCount',
        'u.createdAt',
      ]);

    if (pattern) {
      qb.where('u.username ILIKE :pattern OR u.display_name ILIKE :pattern', {
        pattern,
      });
    }

    return qb
      .orderBy('u.followerCount', 'DESC')
      .limit(limit)
      .getMany();
  }

  private async searchRestaurants(
    pattern: string | null,
    limit: number,
  ): Promise<Restaurant[]> {
    const qb = this.restaurantRepo
      .createQueryBuilder('r')
      .where('r.is_active = true');

    if (pattern) {
      qb.andWhere(
        '(r.name ILIKE :pattern OR r.description ILIKE :pattern OR r.cuisine_type::text ILIKE :pattern)',
        { pattern },
      );
    }

    return qb
      .orderBy('r.followerCount', 'DESC')
      .limit(limit)
      .getMany();
  }

  private async searchPosts(pattern: string | null, limit: number): Promise<any[]> {
    const qb = this.postRepo
      .createQueryBuilder('p')
      .where('p.is_public = true');

    if (pattern) {
      qb.andWhere('p.content ILIKE :pattern', { pattern });
    }

    const posts = await qb
      .orderBy('p.created_at', 'DESC')
      .limit(limit)
      .getMany();

    if (posts.length === 0) return [];

    // Hydrate with author info
    const authorIds = [...new Set(posts.map((p) => p.authorId))];
    const authors = await this.userRepo
      .createQueryBuilder('u')
      .select([
        'u.id',
        'u.username',
        'u.displayName',
        'u.avatarUrl',
        'u.isVerified',
      ])
      .where('u.id IN (:...ids)', { ids: authorIds })
      .getMany();

    const authorMap = new Map(authors.map((a) => [a.id, a]));

    return posts.map((p) => ({
      ...p,
      author: authorMap.get(p.authorId) || null,
    }));
  }
}
