import {
  Injectable,
  ConflictException,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, In } from 'typeorm';
import { Bookmark } from './entities/bookmark.entity';
import { Post } from '../posts/entities/post.entity';

@Injectable()
export class BookmarksService {
  constructor(
    @InjectRepository(Bookmark)
    private readonly bookmarkRepo: Repository<Bookmark>,
    @InjectRepository(Post)
    private readonly postRepo: Repository<Post>,
  ) {}

  async bookmark(userId: string, postId: string): Promise<Bookmark> {
    const post = await this.postRepo.findOne({ where: { id: postId } });
    if (!post) throw new NotFoundException('Post not found');

    const existing = await this.bookmarkRepo.findOne({
      where: { userId, postId },
    });
    if (existing) throw new ConflictException('Already bookmarked');

    const bookmark = this.bookmarkRepo.create({ userId, postId });
    return this.bookmarkRepo.save(bookmark);
  }

  async removeBookmark(userId: string, postId: string): Promise<void> {
    const result = await this.bookmarkRepo.delete({ userId, postId });
    if (result.affected === 0) {
      throw new NotFoundException('Bookmark not found');
    }
  }

  async getBookmarkedPostIds(
    userId: string,
    cursor?: string,
    limit: number = 20,
  ): Promise<{ data: Bookmark[]; nextCursor: string | null }> {
    const qb = this.bookmarkRepo
      .createQueryBuilder('b')
      .where('b.user_id = :userId', { userId })
      .orderBy('b.created_at', 'DESC')
      .take(limit + 1);

    if (cursor) {
      const cursorDate = new Date(
        Buffer.from(cursor, 'base64').toString('utf-8'),
      );
      qb.andWhere('b.created_at < :cursor', { cursor: cursorDate });
    }

    const bookmarks = await qb.getMany();
    let nextCursor: string | null = null;

    if (bookmarks.length > limit) {
      bookmarks.pop();
      const last = bookmarks[bookmarks.length - 1];
      nextCursor = Buffer.from(last.createdAt.toISOString()).toString('base64');
    }

    return { data: bookmarks, nextCursor };
  }

  async isBookmarkedByUser(
    userId: string,
    postIds: string[],
  ): Promise<Set<string>> {
    if (!postIds.length) return new Set();

    const bookmarks = await this.bookmarkRepo.find({
      where: { userId, postId: In(postIds) },
      select: ['postId'],
    });

    return new Set(bookmarks.map((b) => b.postId));
  }
}
