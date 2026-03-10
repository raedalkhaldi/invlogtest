import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, In } from 'typeorm';
import { Conversation, Message } from './entities/message.entity';
import { User } from '../users/entities/user.entity';

@Injectable()
export class MessagesService {
  constructor(
    @InjectRepository(Conversation)
    private readonly conversationRepo: Repository<Conversation>,
    @InjectRepository(Message)
    private readonly messageRepo: Repository<Message>,
    @InjectRepository(User)
    private readonly userRepo: Repository<User>,
  ) {}

  async getConversations(
    userId: string,
    cursor?: string,
    limit: number = 20,
  ): Promise<{ data: Conversation[]; nextCursor: string | null }> {
    const qb = this.conversationRepo
      .createQueryBuilder('c')
      .where(
        '(c.participant_one_id = :userId OR c.participant_two_id = :userId)',
        { userId },
      )
      .andWhere('c.last_message_at IS NOT NULL')
      .orderBy('c.last_message_at', 'DESC')
      .take(limit + 1);

    if (cursor) {
      const cursorDate = new Date(
        Buffer.from(cursor, 'base64').toString('utf-8'),
      );
      qb.andWhere('c.last_message_at < :cursor', { cursor: cursorDate });
    }

    const conversations = await qb.getMany();

    let nextCursor: string | null = null;
    if (conversations.length > limit) {
      conversations.pop();
      const last = conversations[conversations.length - 1];
      nextCursor = Buffer.from(last.lastMessageAt.toISOString()).toString(
        'base64',
      );
    }

    // Hydrate other user + unread counts
    await this.hydrateConversations(conversations, userId);

    return { data: conversations, nextCursor };
  }

  async startConversation(
    userId: string,
    otherUserId: string,
  ): Promise<Conversation> {
    if (userId === otherUserId) {
      throw new BadRequestException('Cannot message yourself');
    }

    const otherUser = await this.userRepo.findOne({
      where: { id: otherUserId },
    });
    if (!otherUser) throw new NotFoundException('User not found');

    // Store lexicographically to ensure unique constraint works
    const [p1, p2] =
      userId < otherUserId
        ? [userId, otherUserId]
        : [otherUserId, userId];

    const existing = await this.conversationRepo.findOne({
      where: { participantOneId: p1, participantTwoId: p2 },
    });
    if (existing) {
      await this.hydrateConversations([existing], userId);
      return existing;
    }

    const conversation = this.conversationRepo.create({
      participantOneId: p1,
      participantTwoId: p2,
    });
    const saved = await this.conversationRepo.save(conversation);
    await this.hydrateConversations([saved], userId);
    return saved;
  }

  async getMessages(
    userId: string,
    conversationId: string,
    cursor?: string,
    limit: number = 30,
  ): Promise<{ data: Message[]; nextCursor: string | null }> {
    const conversation = await this.conversationRepo.findOne({
      where: { id: conversationId },
    });
    if (!conversation) throw new NotFoundException('Conversation not found');
    if (
      conversation.participantOneId !== userId &&
      conversation.participantTwoId !== userId
    ) {
      throw new ForbiddenException('Not a participant');
    }

    const qb = this.messageRepo
      .createQueryBuilder('m')
      .where('m.conversation_id = :conversationId', { conversationId })
      .orderBy('m.created_at', 'DESC')
      .take(limit + 1);

    if (cursor) {
      const cursorDate = new Date(
        Buffer.from(cursor, 'base64').toString('utf-8'),
      );
      qb.andWhere('m.created_at < :cursor', { cursor: cursorDate });
    }

    const messages = await qb.getMany();

    let nextCursor: string | null = null;
    if (messages.length > limit) {
      messages.pop();
      const last = messages[messages.length - 1];
      nextCursor = Buffer.from(last.createdAt.toISOString()).toString('base64');
    }

    return { data: messages, nextCursor };
  }

  async sendMessage(
    userId: string,
    conversationId: string,
    content: string,
  ): Promise<Message> {
    const conversation = await this.conversationRepo.findOne({
      where: { id: conversationId },
    });
    if (!conversation) throw new NotFoundException('Conversation not found');
    if (
      conversation.participantOneId !== userId &&
      conversation.participantTwoId !== userId
    ) {
      throw new ForbiddenException('Not a participant');
    }

    const message = this.messageRepo.create({
      conversationId,
      senderId: userId,
      content,
    });
    const saved = await this.messageRepo.save(message);

    // Update conversation last message
    await this.conversationRepo.update(conversationId, {
      lastMessageText:
        content.length > 100 ? content.substring(0, 100) + '...' : content,
      lastMessageAt: saved.createdAt,
    });

    return saved;
  }

  async markAsRead(
    userId: string,
    conversationId: string,
  ): Promise<void> {
    const conversation = await this.conversationRepo.findOne({
      where: { id: conversationId },
    });
    if (!conversation) throw new NotFoundException('Conversation not found');
    if (
      conversation.participantOneId !== userId &&
      conversation.participantTwoId !== userId
    ) {
      throw new ForbiddenException('Not a participant');
    }

    // Mark all unread messages from the other user as read
    await this.messageRepo
      .createQueryBuilder()
      .update(Message)
      .set({ isRead: true })
      .where('conversation_id = :conversationId', { conversationId })
      .andWhere('sender_id != :userId', { userId })
      .andWhere('is_read = false')
      .execute();
  }

  private async hydrateConversations(
    conversations: Conversation[],
    currentUserId: string,
  ): Promise<void> {
    if (!conversations.length) return;

    // Collect other user IDs
    const otherUserIds = conversations.map((c) =>
      c.participantOneId === currentUserId
        ? c.participantTwoId
        : c.participantOneId,
    );

    const uniqueIds = [...new Set(otherUserIds)];
    const users = await this.userRepo
      .createQueryBuilder('u')
      .select([
        'u.id',
        'u.username',
        'u.displayName',
        'u.avatarUrl',
        'u.isVerified',
      ])
      .where('u.id IN (:...ids)', { ids: uniqueIds })
      .getMany();
    const userMap = new Map(users.map((u) => [u.id, u]));

    // Batch fetch unread counts
    const conversationIds = conversations.map((c) => c.id);
    const unreadCounts = await this.messageRepo
      .createQueryBuilder('m')
      .select('m.conversation_id', 'conversationId')
      .addSelect('COUNT(*)', 'count')
      .where('m.conversation_id IN (:...ids)', { ids: conversationIds })
      .andWhere('m.sender_id != :userId', { userId: currentUserId })
      .andWhere('m.is_read = false')
      .groupBy('m.conversation_id')
      .getRawMany();
    const unreadMap = new Map(
      unreadCounts.map((r: { conversationId: string; count: string }) => [
        r.conversationId,
        parseInt(r.count, 10),
      ]),
    );

    for (const conv of conversations) {
      const otherId =
        conv.participantOneId === currentUserId
          ? conv.participantTwoId
          : conv.participantOneId;
      conv.otherUser = userMap.get(otherId);
      conv.unreadCount = unreadMap.get(conv.id) ?? 0;
    }
  }
}
