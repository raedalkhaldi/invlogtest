import { Injectable, ConflictException, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, DataSource } from 'typeorm';
import { Like } from './entities/like.entity';
import { Post } from '../posts/entities/post.entity';
import { Comment } from '../comments/entities/comment.entity';
import { NotificationsService } from '../notifications/notifications.service';

@Injectable()
export class LikesService {
  constructor(
    @InjectRepository(Like)
    private readonly likeRepo: Repository<Like>,
    @InjectRepository(Post)
    private readonly postRepo: Repository<Post>,
    @InjectRepository(Comment)
    private readonly commentRepo: Repository<Comment>,
    private readonly notificationsService: NotificationsService,
    private readonly dataSource: DataSource,
  ) {}

  async likePost(userId: string, postId: string): Promise<Like> {
    return this.dataSource.transaction(async (manager) => {
      const post = await manager.findOne(Post, { where: { id: postId } });
      if (!post) {
        throw new NotFoundException('Post not found');
      }

      const existing = await manager.findOne(Like, {
        where: { userId, targetType: 'post', targetId: postId },
      });
      if (existing) {
        throw new ConflictException('Already liked');
      }

      const like = manager.create(Like, {
        userId,
        targetType: 'post',
        targetId: postId,
      });

      const saved = await manager.save(like);

      await manager
        .createQueryBuilder()
        .update(Post)
        .set({ likeCount: () => '"like_count" + 1' })
        .where('id = :id', { id: postId })
        .execute();

      await this.notificationsService.create({
        recipientId: post.authorId,
        actorId: userId,
        type: 'like_post',
        targetType: 'post',
        targetId: postId,
      });

      return saved;
    });
  }

  async unlikePost(userId: string, postId: string): Promise<void> {
    await this.dataSource.transaction(async (manager) => {
      const like = await manager.findOne(Like, {
        where: { userId, targetType: 'post', targetId: postId },
      });
      if (!like) {
        throw new NotFoundException('Like not found');
      }

      await manager.remove(like);

      await manager
        .createQueryBuilder()
        .update(Post)
        .set({ likeCount: () => 'GREATEST("like_count" - 1, 0)' })
        .where('id = :id', { id: postId })
        .execute();
    });
  }

  async likeComment(userId: string, commentId: string): Promise<Like> {
    const comment = await this.commentRepo.findOne({
      where: { id: commentId },
    });
    if (!comment) {
      throw new NotFoundException('Comment not found');
    }

    const existing = await this.likeRepo.findOne({
      where: { userId, targetType: 'comment', targetId: commentId },
    });
    if (existing) {
      throw new ConflictException('Already liked');
    }

    const like = this.likeRepo.create({
      userId,
      targetType: 'comment',
      targetId: commentId,
    });

    const saved = await this.likeRepo.save(like);

    await this.commentRepo
      .createQueryBuilder()
      .update(Comment)
      .set({ likeCount: () => '"like_count" + 1' })
      .where('id = :id', { id: commentId })
      .execute();

    await this.notificationsService.create({
      recipientId: comment.authorId,
      actorId: userId,
      type: 'like_comment',
      targetType: 'comment',
      targetId: commentId,
    });

    return saved;
  }

  async unlikeComment(userId: string, commentId: string): Promise<void> {
    const like = await this.likeRepo.findOne({
      where: { userId, targetType: 'comment', targetId: commentId },
    });
    if (!like) {
      throw new NotFoundException('Like not found');
    }

    await this.likeRepo.remove(like);

    await this.commentRepo
      .createQueryBuilder()
      .update(Comment)
      .set({ likeCount: () => 'GREATEST("like_count" - 1, 0)' })
      .where('id = :id', { id: commentId })
      .execute();
  }

  async hasUserLiked(
    userId: string,
    targetType: 'post' | 'comment',
    targetId: string,
  ): Promise<boolean> {
    const count = await this.likeRepo.count({
      where: { userId, targetType, targetId },
    });
    return count > 0;
  }
}
