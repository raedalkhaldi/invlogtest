import {
  Injectable,
  NotFoundException,
  ForbiddenException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, IsNull, In } from 'typeorm';
import { Comment } from './entities/comment.entity';
import { CreateCommentDto, UpdateCommentDto } from './dto/create-comment.dto';
import { Post } from '../posts/entities/post.entity';
import { User } from '../users/entities/user.entity';
import { NotificationsService } from '../notifications/notifications.service';

@Injectable()
export class CommentsService {
  constructor(
    @InjectRepository(Comment)
    private readonly commentRepo: Repository<Comment>,
    @InjectRepository(Post)
    private readonly postRepo: Repository<Post>,
    @InjectRepository(User)
    private readonly userRepo: Repository<User>,
    private readonly notificationsService: NotificationsService,
  ) {}

  async create(
    postId: string,
    authorId: string,
    dto: CreateCommentDto,
  ): Promise<any> {
    const post = await this.postRepo.findOne({ where: { id: postId } });
    if (!post) {
      throw new NotFoundException('Post not found');
    }

    if (dto.parentId) {
      const parent = await this.commentRepo.findOne({
        where: { id: dto.parentId, postId },
      });
      if (!parent) {
        throw new NotFoundException('Parent comment not found');
      }
    }

    const comment = this.commentRepo.create({
      postId,
      authorId,
      content: dto.content,
      parentId: dto.parentId,
    });

    const saved = await this.commentRepo.save(comment);

    await this.postRepo
      .createQueryBuilder()
      .update(Post)
      .set({ commentCount: () => '"comment_count" + 1' })
      .where('id = :id', { id: postId })
      .execute();

    await this.notificationsService.create({
      recipientId: post.authorId,
      actorId: authorId,
      type: 'comment',
      targetType: 'post',
      targetId: postId,
    });

    // Hydrate with author info
    const author = await this.userRepo.findOne({
      where: { id: authorId },
      select: ['id', 'username', 'displayName', 'avatarUrl', 'isVerified', 'isPrivate', 'followerCount', 'followingCount', 'postCount'],
    });

    return { ...saved, author: author || null };
  }

  async findByPostId(
    postId: string,
    page: number = 1,
    perPage: number = 20,
  ): Promise<{ data: any[]; total: number }> {
    const [data, total] = await this.commentRepo.findAndCount({
      where: { postId, parentId: IsNull() },
      order: { createdAt: 'ASC' },
      skip: (page - 1) * perPage,
      take: perPage,
    });

    if (data.length === 0) return { data: [], total };

    // Hydrate with author info
    const authorIds = [...new Set(data.map((c) => c.authorId))];
    const authors = await this.userRepo.find({
      where: { id: In(authorIds) },
      select: ['id', 'username', 'displayName', 'avatarUrl', 'isVerified', 'isPrivate', 'followerCount', 'followingCount', 'postCount'],
    });
    const authorMap = new Map(authors.map((a) => [a.id, a]));

    const hydrated = data.map((c) => ({
      ...c,
      author: authorMap.get(c.authorId) || null,
    }));

    return { data: hydrated, total };
  }

  async findReplies(
    parentId: string,
    page: number = 1,
    perPage: number = 20,
  ): Promise<{ data: Comment[]; total: number }> {
    const [data, total] = await this.commentRepo.findAndCount({
      where: { parentId },
      order: { createdAt: 'ASC' },
      skip: (page - 1) * perPage,
      take: perPage,
    });

    return { data, total };
  }

  async findById(id: string): Promise<Comment> {
    const comment = await this.commentRepo.findOne({ where: { id } });
    if (!comment) {
      throw new NotFoundException('Comment not found');
    }
    return comment;
  }

  async update(
    id: string,
    userId: string,
    dto: UpdateCommentDto,
  ): Promise<Comment> {
    const comment = await this.findById(id);
    if (comment.authorId !== userId) {
      throw new ForbiddenException('You can only edit your own comments');
    }
    comment.content = dto.content;
    return this.commentRepo.save(comment);
  }

  async remove(id: string, userId: string): Promise<void> {
    const comment = await this.findById(id);

    // Allow comment author OR post owner to delete
    if (comment.authorId !== userId) {
      const post = await this.postRepo.findOne({ where: { id: comment.postId } });
      if (!post || post.authorId !== userId) {
        throw new ForbiddenException('You can only delete your own comments or comments on your posts');
      }
    }

    await this.commentRepo.softRemove(comment);

    await this.postRepo
      .createQueryBuilder()
      .update(Post)
      .set({ commentCount: () => 'GREATEST("comment_count" - 1, 0)' })
      .where('id = :id', { id: comment.postId })
      .execute();
  }

  async incrementLikeCount(id: string): Promise<void> {
    await this.commentRepo
      .createQueryBuilder()
      .update(Comment)
      .set({ likeCount: () => '"like_count" + 1' })
      .where('id = :id', { id })
      .execute();
  }

  async decrementLikeCount(id: string): Promise<void> {
    await this.commentRepo
      .createQueryBuilder()
      .update(Comment)
      .set({ likeCount: () => 'GREATEST("like_count" - 1, 0)' })
      .where('id = :id', { id })
      .execute();
  }
}
