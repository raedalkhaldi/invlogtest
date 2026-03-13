import {
  Injectable,
  ConflictException,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Block } from './entities/block.entity';
import { User } from '../users/entities/user.entity';
import { Follow } from '../follows/entities/follow.entity';

@Injectable()
export class BlocksService {
  constructor(
    @InjectRepository(Block)
    private readonly blockRepo: Repository<Block>,
    @InjectRepository(User)
    private readonly userRepo: Repository<User>,
    @InjectRepository(Follow)
    private readonly followRepo: Repository<Follow>,
  ) {}

  async blockUser(blockerId: string, blockedUserId: string): Promise<Block> {
    if (blockerId === blockedUserId) {
      throw new ConflictException('Cannot block yourself');
    }

    const target = await this.userRepo.findOne({ where: { id: blockedUserId } });
    if (!target) {
      throw new NotFoundException('User not found');
    }

    const existing = await this.blockRepo.findOne({
      where: { blockerId, blockedUserId },
    });
    if (existing) {
      throw new ConflictException('User already blocked');
    }

    const block = this.blockRepo.create({ blockerId, blockedUserId });
    const saved = await this.blockRepo.save(block);

    // Auto-unfollow in both directions
    await this.followRepo.delete({
      followerId: blockerId,
      targetType: 'user',
      targetId: blockedUserId,
    });
    await this.followRepo.delete({
      followerId: blockedUserId,
      targetType: 'user',
      targetId: blockerId,
    });

    // Decrement follower/following counts
    await this.userRepo
      .createQueryBuilder()
      .update(User)
      .set({ followingCount: () => 'GREATEST("following_count" - 1, 0)' })
      .where('id IN (:...ids)', { ids: [blockerId, blockedUserId] })
      .execute();
    await this.userRepo
      .createQueryBuilder()
      .update(User)
      .set({ followerCount: () => 'GREATEST("follower_count" - 1, 0)' })
      .where('id IN (:...ids)', { ids: [blockerId, blockedUserId] })
      .execute();

    return saved;
  }

  async unblockUser(blockerId: string, blockedUserId: string): Promise<void> {
    const block = await this.blockRepo.findOne({
      where: { blockerId, blockedUserId },
    });
    if (!block) {
      throw new NotFoundException('Block not found');
    }
    await this.blockRepo.remove(block);
  }

  async getBlockedUserIds(userId: string): Promise<string[]> {
    const blocks = await this.blockRepo.find({
      where: { blockerId: userId },
      select: ['blockedUserId'],
    });
    return blocks.map((b) => b.blockedUserId);
  }

  async getBlockedByUserIds(userId: string): Promise<string[]> {
    const blocks = await this.blockRepo.find({
      where: { blockedUserId: userId },
      select: ['blockerId'],
    });
    return blocks.map((b) => b.blockerId);
  }

  async getAllBlockRelatedIds(userId: string): Promise<string[]> {
    const [blocked, blockedBy] = await Promise.all([
      this.getBlockedUserIds(userId),
      this.getBlockedByUserIds(userId),
    ]);
    return [...new Set([...blocked, ...blockedBy])];
  }

  async isBlocked(blockerId: string, blockedUserId: string): Promise<boolean> {
    const block = await this.blockRepo.findOne({
      where: { blockerId, blockedUserId },
    });
    return !!block;
  }
}
