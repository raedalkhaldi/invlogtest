import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, In } from 'typeorm';
import { Notification, DeviceToken } from './entities/notification.entity';
import { User } from '../users/entities/user.entity';
import { ApnsPushService } from './apns-push.service';

@Injectable()
export class NotificationsService {
  private readonly logger = new Logger(NotificationsService.name);

  constructor(
    @InjectRepository(Notification)
    private readonly notificationRepo: Repository<Notification>,
    @InjectRepository(DeviceToken)
    private readonly deviceTokenRepo: Repository<DeviceToken>,
    @InjectRepository(User)
    private readonly userRepo: Repository<User>,
    private readonly apnsPushService: ApnsPushService,
  ) {}

  async create(data: {
    recipientId: string;
    actorId?: string;
    type: string;
    targetType?: string;
    targetId?: string;
    message?: string;
  }): Promise<Notification | null> {
    // Don't create self-notifications
    if (data.actorId && data.actorId === data.recipientId) {
      return null;
    }
    const notification = this.notificationRepo.create(data);
    const saved = await this.notificationRepo.save(notification);

    // Send push notification (fire-and-forget — never blocks API response)
    this.sendPushForNotification(saved, data.actorId).catch((err) => {
      this.logger.error(`Push notification failed: ${err.message}`);
    });

    return saved;
  }

  async findByRecipientId(
    recipientId: string,
    limit: number = 50,
  ): Promise<any[]> {
    const notifications = await this.notificationRepo.find({
      where: { recipientId },
      order: { createdAt: 'DESC' },
      take: limit,
    });

    if (notifications.length === 0) return [];

    // Hydrate actor
    const actorIds = [
      ...new Set(
        notifications.map((n) => n.actorId).filter((id): id is string => !!id),
      ),
    ];

    let actorMap = new Map<string, Partial<User>>();
    if (actorIds.length > 0) {
      const actors = await this.userRepo
        .createQueryBuilder('u')
        .select([
          'u.id',
          'u.username',
          'u.displayName',
          'u.avatarUrl',
          'u.isVerified',
          'u.isPrivate',
          'u.followerCount',
          'u.followingCount',
          'u.postCount',
        ])
        .where('u.id IN (:...ids)', { ids: actorIds })
        .getMany();
      actorMap = new Map(actors.map((a) => [a.id, a]));
    }

    return notifications.map((n) => ({
      ...n,
      actor: n.actorId ? actorMap.get(n.actorId) || null : null,
    }));
  }

  async markAsRead(id: string, userId: string): Promise<Notification> {
    const notification = await this.notificationRepo.findOne({
      where: { id, recipientId: userId },
    });
    if (!notification) {
      throw new NotFoundException('Notification not found');
    }
    notification.isRead = true;
    return this.notificationRepo.save(notification);
  }

  async markAllAsRead(userId: string): Promise<void> {
    await this.notificationRepo
      .createQueryBuilder()
      .update(Notification)
      .set({ isRead: true })
      .where('recipient_id = :userId', { userId })
      .andWhere('is_read = false')
      .execute();
  }

  async getUnreadCount(userId: string): Promise<number> {
    return this.notificationRepo.count({
      where: { recipientId: userId, isRead: false },
    });
  }

  async registerDeviceToken(
    userId: string,
    token: string,
    platform: string,
  ): Promise<DeviceToken> {
    // Check if token already exists for this user
    let deviceToken = await this.deviceTokenRepo.findOne({
      where: { userId, token },
    });

    if (deviceToken) {
      deviceToken.isActive = true;
      deviceToken.platform = platform;
      deviceToken.updatedAt = new Date();
      return this.deviceTokenRepo.save(deviceToken);
    }

    deviceToken = this.deviceTokenRepo.create({
      userId,
      token,
      platform,
    });

    return this.deviceTokenRepo.save(deviceToken);
  }

  // MARK: - Push Notifications

  private async sendPushForNotification(
    notification: Notification,
    actorId?: string,
  ): Promise<void> {
    // Look up active device tokens for recipient
    const deviceTokens = await this.deviceTokenRepo.find({
      where: {
        userId: notification.recipientId,
        isActive: true,
        platform: 'ios',
      },
    });

    if (deviceTokens.length === 0) return;

    // Look up actor name for the push message
    let actorName = 'Someone';
    if (actorId) {
      const actor = await this.userRepo.findOne({
        where: { id: actorId },
        select: ['id', 'displayName', 'username'],
      });
      if (actor) {
        actorName = actor.displayName || actor.username;
      }
    }

    // Build push payload based on notification type
    const { title, body } = this.buildPushContent(
      notification.type,
      actorName,
    );

    // Get unread count for badge
    const unreadCount = await this.getUnreadCount(notification.recipientId);

    const tokens = deviceTokens.map((dt) => dt.token);
    const result = await this.apnsPushService.sendPush(tokens, {
      title,
      body,
      badge: unreadCount,
      data: {
        notificationId: notification.id,
        type: notification.type,
        ...(notification.targetType
          ? { targetType: notification.targetType }
          : {}),
        ...(notification.targetId ? { targetId: notification.targetId } : {}),
      },
    });

    // Deactivate invalid tokens
    if (result.invalidTokens.length > 0) {
      await this.deviceTokenRepo
        .createQueryBuilder()
        .update(DeviceToken)
        .set({ isActive: false })
        .where('token IN (:...tokens)', { tokens: result.invalidTokens })
        .execute();
    }
  }

  private buildPushContent(
    type: string,
    actorName: string,
  ): { title: string; body: string } {
    switch (type) {
      case 'follow':
        return {
          title: 'New Follower',
          body: `${actorName} started following you`,
        };
      case 'like_post':
        return {
          title: 'Post Liked',
          body: `${actorName} liked your post`,
        };
      case 'like_comment':
        return {
          title: 'Comment Liked',
          body: `${actorName} liked your comment`,
        };
      case 'comment':
        return {
          title: 'New Comment',
          body: `${actorName} commented on your post`,
        };
      default:
        return {
          title: 'Invlog',
          body: `${actorName} interacted with your content`,
        };
    }
  }
}
