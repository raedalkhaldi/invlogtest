import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, In, IsNull } from 'typeorm';
import { Post, PostMedia } from './entities/post.entity';
import { CreatePostDto, UpdatePostDto } from './dto/create-post.dto';

@Injectable()
export class PostsService {
  constructor(
    @InjectRepository(Post)
    private readonly postRepo: Repository<Post>,
    @InjectRepository(PostMedia)
    private readonly mediaRepo: Repository<PostMedia>,
  ) {}

  async create(authorId: string, dto: CreatePostDto): Promise<Post> {
    const post = this.postRepo.create({
      authorId,
      content: dto.content,
      restaurantId: dto.restaurantId,
      rating: dto.rating,
      locationName: dto.locationName,
      isPublic: dto.isPublic ?? true,
    });

    if (dto.latitude != null && dto.longitude != null) {
      post.latitude = dto.latitude;
      post.longitude = dto.longitude;
    }

    const saved = await this.postRepo.save(post);

    if (dto.mediaIds?.length) {
      // Validate that all media belong to the user and are unattached
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

    return this.findById(saved.id);
  }

  async findById(id: string): Promise<Post> {
    const post = await this.postRepo.findOne({ where: { id } });
    if (!post) {
      throw new NotFoundException('Post not found');
    }
    return post;
  }

  async findByIds(ids: string[]): Promise<Post[]> {
    if (!ids.length) return [];
    return this.postRepo.find({ where: { id: In(ids) } });
  }

  async findByAuthor(
    authorId: string,
    page: number = 1,
    perPage: number = 20,
  ): Promise<{ data: Post[]; total: number }> {
    const [data, total] = await this.postRepo.findAndCount({
      where: { authorId },
      order: { createdAt: 'DESC' },
      skip: (page - 1) * perPage,
      take: perPage,
    });
    return { data, total };
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
    let nextCursor: string | null = null;

    if (posts.length > limit) {
      posts.pop();
      const last = posts[posts.length - 1];
      nextCursor = Buffer.from(last.createdAt.toISOString()).toString('base64');
    }

    return { data: posts, nextCursor };
  }
}
