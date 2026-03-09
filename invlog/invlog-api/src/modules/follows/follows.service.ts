import {
  Injectable,
  ConflictException,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, In } from 'typeorm';
import { Follow } from './entities/follow.entity';
import { User } from '../users/entities/user.entity';
import { Restaurant } from '../restaurants/entities/restaurant.entity';
import { NotificationsService } from '../notifications/notifications.service';

@Injectable()
export class FollowsService {
  constructor(
    @InjectRepository(Follow)
    private readonly followRepo: Repository<Follow>,
    @InjectRepository(User)
    private readonly userRepo: Repository<User>,
    @InjectRepository(Restaurant)
    private readonly restaurantRepo: Repository<Restaurant>,
    private readonly notificationsService: NotificationsService,
  ) {}

  async followUser(followerId: string, targetId: string): Promise<Follow> {
    if (followerId === targetId) {
      throw new ConflictException('Cannot follow yourself');
    }

    const target = await this.userRepo.findOne({ where: { id: targetId } });
    if (!target) {
      throw new NotFoundException('User not found');
    }

    const existing = await this.followRepo.findOne({
      where: { followerId, targetType: 'user', targetId },
    });
    if (existing) {
      throw new ConflictException('Already following this user');
    }

    const follow = this.followRepo.create({
      followerId,
      targetType: 'user',
      targetId,
    });

    const saved = await this.followRepo.save(follow);

    // Increment follower count on target user
    await this.userRepo
      .createQueryBuilder()
      .update(User)
      .set({ followerCount: () => '"follower_count" + 1' })
      .where('id = :id', { id: targetId })
      .execute();

    // Increment following count on current user
    await this.userRepo
      .createQueryBuilder()
      .update(User)
      .set({ followingCount: () => '"following_count" + 1' })
      .where('id = :id', { id: followerId })
      .execute();

    // Create notification
    await this.notificationsService.create({
      recipientId: targetId,
      actorId: followerId,
      type: 'follow',
      targetType: 'user',
      targetId: followerId,
    });

    return saved;
  }

  async unfollowUser(followerId: string, targetId: string): Promise<void> {
    const follow = await this.followRepo.findOne({
      where: { followerId, targetType: 'user', targetId },
    });
    if (!follow) {
      throw new NotFoundException('Not following this user');
    }

    await this.followRepo.remove(follow);

    await this.userRepo
      .createQueryBuilder()
      .update(User)
      .set({ followerCount: () => 'GREATEST("follower_count" - 1, 0)' })
      .where('id = :id', { id: targetId })
      .execute();

    await this.userRepo
      .createQueryBuilder()
      .update(User)
      .set({ followingCount: () => 'GREATEST("following_count" - 1, 0)' })
      .where('id = :id', { id: followerId })
      .execute();
  }

  async followRestaurant(
    followerId: string,
    restaurantId: string,
  ): Promise<Follow> {
    const restaurant = await this.restaurantRepo.findOne({
      where: { id: restaurantId },
    });
    if (!restaurant) {
      throw new NotFoundException('Restaurant not found');
    }

    const existing = await this.followRepo.findOne({
      where: {
        followerId,
        targetType: 'restaurant',
        targetId: restaurantId,
      },
    });
    if (existing) {
      throw new ConflictException('Already following this restaurant');
    }

    const follow = this.followRepo.create({
      followerId,
      targetType: 'restaurant',
      targetId: restaurantId,
    });

    const saved = await this.followRepo.save(follow);

    await this.restaurantRepo
      .createQueryBuilder()
      .update(Restaurant)
      .set({ followerCount: () => '"follower_count" + 1' })
      .where('id = :id', { id: restaurantId })
      .execute();

    return saved;
  }

  async unfollowRestaurant(
    followerId: string,
    restaurantId: string,
  ): Promise<void> {
    const follow = await this.followRepo.findOne({
      where: {
        followerId,
        targetType: 'restaurant',
        targetId: restaurantId,
      },
    });
    if (!follow) {
      throw new NotFoundException('Not following this restaurant');
    }

    await this.followRepo.remove(follow);

    await this.restaurantRepo
      .createQueryBuilder()
      .update(Restaurant)
      .set({ followerCount: () => 'GREATEST("follower_count" - 1, 0)' })
      .where('id = :id', { id: restaurantId })
      .execute();
  }

  async getFollowers(
    targetId: string,
    targetType: 'user' | 'restaurant',
    page: number = 1,
    perPage: number = 20,
  ): Promise<{ data: Follow[]; total: number }> {
    const [data, total] = await this.followRepo.findAndCount({
      where: { targetId, targetType },
      order: { createdAt: 'DESC' },
      skip: (page - 1) * perPage,
      take: perPage,
    });
    return { data, total };
  }

  async getFollowing(
    followerId: string,
    targetType: 'user' | 'restaurant',
    page: number = 1,
    perPage: number = 20,
  ): Promise<{ data: Follow[]; total: number }> {
    const [data, total] = await this.followRepo.findAndCount({
      where: { followerId, targetType },
      order: { createdAt: 'DESC' },
      skip: (page - 1) * perPage,
      take: perPage,
    });
    return { data, total };
  }

  async getFollowedUserIds(followerId: string): Promise<string[]> {
    const follows = await this.followRepo.find({
      where: { followerId, targetType: 'user' },
      select: ['targetId'],
    });
    return follows.map((f) => f.targetId);
  }

  async isFollowing(
    followerId: string,
    targetType: 'user' | 'restaurant',
    targetId: string,
  ): Promise<boolean> {
    const count = await this.followRepo.count({
      where: { followerId, targetType, targetId },
    });
    return count > 0;
  }

  async getFollowersWithUsers(
    targetId: string,
    currentUserId: string,
    page: number = 1,
    perPage: number = 20,
  ): Promise<{ data: any[]; total: number }> {
    const [follows, total] = await this.followRepo.findAndCount({
      where: { targetType: 'user', targetId },
      skip: (page - 1) * perPage,
      take: perPage,
      order: { createdAt: 'DESC' },
    });

    const followerIds = follows.map((f) => f.followerId);
    if (!followerIds.length) return { data: [], total };

    const users = await this.userRepo.find({ where: { id: In(followerIds) } });

    // Check which ones the current user follows
    const currentUserFollows = await this.followRepo.find({
      where: {
        followerId: currentUserId,
        targetType: 'user',
        targetId: In(followerIds),
      },
    });
    const followedSet = new Set(currentUserFollows.map((f) => f.targetId));

    const result = users.map((u) => {
      const { passwordHash, ...safe } = u as any;
      return { ...safe, isFollowedByMe: followedSet.has(u.id) };
    });

    return { data: result, total };
  }

  async getFollowingWithUsers(
    followerId: string,
    currentUserId: string,
    page: number = 1,
    perPage: number = 20,
  ): Promise<{ data: any[]; total: number }> {
    const [follows, total] = await this.followRepo.findAndCount({
      where: { followerId, targetType: 'user' },
      skip: (page - 1) * perPage,
      take: perPage,
      order: { createdAt: 'DESC' },
    });

    const followedIds = follows.map((f) => f.targetId);
    if (!followedIds.length) return { data: [], total };

    const users = await this.userRepo.find({ where: { id: In(followedIds) } });

    const currentUserFollows = await this.followRepo.find({
      where: {
        followerId: currentUserId,
        targetType: 'user',
        targetId: In(followedIds),
      },
    });
    const followedSet = new Set(currentUserFollows.map((f) => f.targetId));

    const result = users.map((u) => {
      const { passwordHash, ...safe } = u as any;
      return { ...safe, isFollowedByMe: followedSet.has(u.id) };
    });

    return { data: result, total };
  }
}
