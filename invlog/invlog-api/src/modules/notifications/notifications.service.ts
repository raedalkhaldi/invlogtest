import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, In } from 'typeorm';
import { Notification, DeviceToken } from './entities/notification.entity';
import { User } from '../users/entities/user.entity';

@Injectable()
export class NotificationsService {
  constructor(
    @InjectRepository(Notification)
    private readonly notificationRepo: Repository<Notification>,
    @InjectRepository(DeviceToken)
    private readonly deviceTokenRepo: Repository<DeviceToken>,
    @InjectRepository(User)
    private readonly userRepo: Repository<User>,
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
    return this.notificationRepo.save(notification);
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
}
