import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, In, IsNull } from 'typeorm';
import { Post, PostMedia } from './entities/post.entity';
import { User } from '../users/entities/user.entity';
import { Restaurant } from '../restaurants/entities/restaurant.entity';
import { CheckIn } from '../checkins/entities/checkin.entity';
import { CreatePostDto, UpdatePostDto } from './dto/create-post.dto';

@Injectable()
export class PostsService {
  constructor(
    @InjectRepository(Post)
    private readonly postRepo: Repository<Post>,
    @InjectRepository(PostMedia)
    private readonly mediaRepo: Repository<PostMedia>,
    @InjectRepository(User)
    private readonly userRepo: Repository<User>,
    @InjectRepository(Restaurant)
    private readonly restaurantRepo: Repository<Restaurant>,
    @InjectRepository(CheckIn)
    private readonly checkinRepo: Repository<CheckIn>,
  ) {}

  /**
   * Hydrate posts with author and restaurant data using batch queries.
   * Avoids TypeORM join metadata issues entirely.
   */
  private async hydratePosts(posts: Post[]): Promise<Post[]> {
    if (!posts.length) return posts;

    const postIds = posts.map((p) => p.id);

    // Batch-fetch media
    const allMedia = await this.mediaRepo.find({
      where: { postId: In(postIds) },
      order: { sortOrder: 'ASC' },
    });
    const mediaMap = new Map<string, PostMedia[]>();
    for (const m of allMedia) {
      const list = mediaMap.get(m.postId!) ?? [];
      list.push(m);
      mediaMap.set(m.postId!, list);
    }
    for (const post of posts) {
      post.media = mediaMap.get(post.id) ?? [];
    }

    // Batch-fetch authors
    const authorIds = [...new Set(posts.map((p) => p.authorId).filter(Boolean))];
    if (authorIds.length) {
      const authors = await this.userRepo
        .createQueryBuilder('u')
        .select(['u.id', 'u.username', 'u.displayName', 'u.avatarUrl', 'u.isVerified', 'u.bio', 'u.followerCount', 'u.followingCount', 'u.postCount', 'u.isPrivate', 'u.coverUrl'])
        .where('u.id IN (:...ids)', { ids: authorIds })
        .getMany();
      const authorMap = new Map(authors.map((a) => [a.id, a]));
      for (const post of posts) {
        post.author = authorMap.get(post.authorId);
      }
    }

    // Batch-fetch restaurants
    const restaurantIds = [...new Set(posts.map((p) => p.restaurantId).filter(Boolean))];
    if (restaurantIds.length) {
      const restaurants = await this.restaurantRepo.find({
        where: { id: In(restaurantIds) },
      });
      const restMap = new Map(restaurants.map((r) => [r.id, r]));
      for (const post of posts) {
        if (post.restaurantId) {
          post.restaurant = restMap.get(post.restaurantId);
        }
      }
    }

    return posts;
  }

  async create(authorId: string, dto: CreatePostDto): Promise<Post> {
    const post = this.postRepo.create({
      authorId,
      content: dto.content,
      restaurantId: dto.restaurantId,
      rating: dto.rating,
      locationName: dto.locationName,
      locationAddress: dto.locationAddress,
      isPublic: dto.isPublic ?? true,
    });

    if (dto.latitude != null && dto.longitude != null) {
      post.latitude = dto.latitude;
      post.longitude = dto.longitude;
    }

    const saved = await this.postRepo.save(post);

    if (dto.mediaIds?.length) {
      const ownedMedia = await this.mediaRepo.find({
        where: {
          id: In(dto.mediaIds),
          uploaderId: authorId,
          postId: IsNull(),
        },
      });

      if (ownedMedia.length !== dto.mediaIds.length) {
        throw new BadRequestException(
          'Some media IDs are invalid, do not belong to you, or are already attached to another post',
        );
      }

      await this.mediaRepo
        .createQueryBuilder()
        .update(PostMedia)
        .set({ postId: saved.id })
        .where('id IN (:...ids)', { ids: dto.mediaIds })
        .execute();
    }

    // Increment user's post count
    await this.userRepo
      .createQueryBuilder()
      .update(User)
      .set({ postCount: () => '"post_count" + 1' })
      .where('id = :id', { id: authorId })
      .execute();

    // Auto-create check-in linked to this post
    if (dto.restaurantId) {
      const checkin = this.checkinRepo.create({
        userId: authorId,
        restaurantId: dto.restaurantId,
        postId: saved.id,
      });
      if (dto.latitude != null && dto.longitude != null) {
        checkin.latitude = dto.latitude;
        checkin.longitude = dto.longitude;
      }
      await this.checkinRepo.save(checkin);

      // Increment restaurant check-in count
      await this.restaurantRepo
        .createQueryBuilder()
        .update(Restaurant)
        .set({ checkinCount: () => '"checkin_count" + 1' })
        .where('id = :id', { id: dto.restaurantId })
        .execute();
    }

    return this.findById(saved.id);
  }

  async findById(id: string): Promise<Post> {
    const post = await this.postRepo.findOne({
      where: { id },
    });
    if (!post) {
      throw new NotFoundException('Post not found');
    }
    await this.hydratePosts([post]);
    return post;
  }

  async findByIds(ids: string[]): Promise<Post[]> {
    if (!ids.length) return [];
    const posts = await this.postRepo.find({
      where: { id: In(ids) },
    });
    return this.hydratePosts(posts);
  }

  async findByAuthor(
    authorId: string,
    cursor?: string,
    limit: number = 20,
  ): Promise<{ data: Post[]; nextCursor: string | null }> {
    const qb = this.postRepo
      .createQueryBuilder('post')
      .where('post.author_id = :authorId', { authorId })
      .orderBy('post.created_at', 'DESC')
      .take(limit + 1);

    if (cursor) {
      const cursorDate = new Date(
        Buffer.from(cursor, 'base64').toString('utf-8'),
      );
      qb.andWhere('post.created_at < :cursor', { cursor: cursorDate });
    }

    const posts = await qb.getMany();
    await this.hydratePosts(posts);
    let nextCursor: string | null = null;

    if (posts.length > limit) {
      posts.pop();
      const last = posts[posts.length - 1];
      nextCursor = Buffer.from(last.createdAt.toISOString()).toString('base64');
    }

    return { data: posts, nextCursor };
  }

  async findPaginated(
    page: number = 1,
    perPage: number = 20,
  ): Promise<{ data: Post[]; total: number }> {
    const [data, total] = await this.postRepo.findAndCount({
      where: { isPublic: true },
      order: { createdAt: 'DESC' },
      skip: (page - 1) * perPage,
      take: perPage,
    });
    await this.hydratePosts(data);
    return { data, total };
  }

  async update(id: string, userId: string, dto: UpdatePostDto): Promise<Post> {
    const post = await this.findById(id);
    if (post.authorId !== userId) {
      throw new ForbiddenException('You can only edit your own posts');
    }
    Object.assign(post, dto);
    await this.postRepo.save(post);
    return this.findById(id);
  }

  async remove(id: string, userId: string): Promise<void> {
    const post = await this.findById(id);
    if (post.authorId !== userId) {
      throw new ForbiddenException('You can only delete your own posts');
    }
    await this.postRepo.softRemove(post);

    // Decrement user's post count
    await this.userRepo
      .createQueryBuilder()
      .update(User)
      .set({ postCount: () => 'GREATEST("post_count" - 1, 0)' })
      .where('id = :id', { id: userId })
      .execute();
  }

  async incrementCounter(
    id: string,
    field: 'likeCount' | 'commentCount',
  ): Promise<void> {
    const col = field === 'likeCount' ? 'like_count' : 'comment_count';
    await this.postRepo
      .createQueryBuilder()
      .update(Post)
      .set({ [field]: () => `"${col}" + 1` })
      .where('id = :id', { id })
      .execute();
  }

  async decrementCounter(
    id: string,
    field: 'likeCount' | 'commentCount',
  ): Promise<void> {
    const col = field === 'likeCount' ? 'like_count' : 'comment_count';
    await this.postRepo
      .createQueryBuilder()
      .update(Post)
      .set({ [field]: () => `GREATEST("${col}" - 1, 0)` })
      .where('id = :id', { id })
      .execute();
  }

  async findPublicPosts(
    excludeUserId: string,
    cursor?: string,
    limit: number = 20,
  ): Promise<{ data: Post[]; nextCursor: string | null }> {
    const qb = this.postRepo
      .createQueryBuilder('post')
      .where('post.is_public = true')
      .andWhere('post.author_id != :excludeUserId', { excludeUserId })
      .orderBy('post.created_at', 'DESC')
      .take(limit + 1);

    if (cursor) {
      const cursorDate = new Date(
        Buffer.from(cursor, 'base64').toString('utf-8'),
      );
      qb.andWhere('post.created_at < :cursor', { cursor: cursorDate });
    }

    const posts = await qb.getMany();
    await this.hydratePosts(posts);
    let nextCursor: string | null = null;

    if (posts.length > limit) {
      posts.pop();
      const last = posts[posts.length - 1];
      nextCursor = Buffer.from(last.createdAt.toISOString()).toString('base64');
    }

    return { data: posts, nextCursor };
  }

  async findByAuthorIds(
    authorIds: string[],
    cursor?: string,
    limit: number = 20,
  ): Promise<{ data: Post[]; nextCursor: string | null }> {
    if (!authorIds.length) return { data: [], nextCursor: null };

    const qb = this.postRepo
      .createQueryBuilder('post')
      .where('post.author_id IN (:...authorIds)', { authorIds })
      .andWhere('post.is_public = true')
      .orderBy('post.created_at', 'DESC')
      .take(limit + 1);

    if (cursor) {
      const cursorDate = new Date(
        Buffer.from(cursor, 'base64').toString('utf-8'),
      );
      qb.andWhere('post.created_at < :cursor', { cursor: cursorDate });
    }

    const posts = await qb.getMany();
    await this.hydratePosts(posts);
    let nextCursor: string | null = null;

    if (posts.length > limit) {
      posts.pop();
      const last = posts[posts.length - 1];
      nextCursor = Buffer.from(last.createdAt.toISOString()).toString('base64');
    }

    return { data: posts, nextCursor };
  }
}
