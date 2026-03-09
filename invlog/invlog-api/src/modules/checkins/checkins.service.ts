import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, In } from 'typeorm';
import { CheckIn } from './entities/checkin.entity';
import { CreateCheckInDto } from './dto/create-checkin.dto';
import { Restaurant } from '../restaurants/entities/restaurant.entity';
import { User } from '../users/entities/user.entity';

@Injectable()
export class CheckInsService {
  constructor(
    @InjectRepository(CheckIn)
    private readonly checkinRepo: Repository<CheckIn>,
    @InjectRepository(Restaurant)
    private readonly restaurantRepo: Repository<Restaurant>,
    @InjectRepository(User)
    private readonly userRepo: Repository<User>,
  ) {}

  async create(userId: string, dto: CreateCheckInDto): Promise<CheckIn> {
    const restaurant = await this.restaurantRepo.findOne({
      where: { id: dto.restaurantId },
    });
    if (!restaurant) {
      throw new NotFoundException('Restaurant not found');
    }

    const checkin = this.checkinRepo.create({
      userId,
      restaurantId: dto.restaurantId,
      postId: dto.postId,
    });

    if (dto.latitude != null && dto.longitude != null) {
      checkin.latitude = dto.latitude;
      checkin.longitude = dto.longitude;
    }

    const saved = await this.checkinRepo.save(checkin);

    await this.restaurantRepo
      .createQueryBuilder()
      .update(Restaurant)
      .set({ checkinCount: () => '"checkin_count" + 1' })
      .where('id = :id', { id: dto.restaurantId })
      .execute();

    return saved;
  }

  async findByUserId(
    userId: string,
    page: number = 1,
    perPage: number = 20,
  ): Promise<{ data: any[]; total: number }> {
    const [checkins, total] = await this.checkinRepo.findAndCount({
      where: { userId },
      order: { createdAt: 'DESC' },
      skip: (page - 1) * perPage,
      take: perPage,
    });

    if (checkins.length > 0) {
      const restaurantIds = [
        ...new Set(checkins.map((c) => c.restaurantId)),
      ];
      const restaurants = await this.restaurantRepo.find({
        where: restaurantIds.map((id) => ({ id })),
      });
      const restMap = new Map(restaurants.map((r) => [r.id, r]));
      const data = checkins.map((c) => ({
        ...c,
        restaurant: restMap.get(c.restaurantId) || null,
      }));
      return { data, total };
    }

    return { data: checkins, total };
  }

  async findByRestaurantId(
    restaurantId: string,
    page: number = 1,
    perPage: number = 20,
  ): Promise<{ data: any[]; total: number }> {
    const [checkins, total] = await this.checkinRepo.findAndCount({
      where: { restaurantId },
      order: { createdAt: 'DESC' },
      skip: (page - 1) * perPage,
      take: perPage,
    });

    if (checkins.length > 0) {
      const userIds = [...new Set(checkins.map((c) => c.userId))];
      const users = await this.userRepo.find({
        where: userIds.map((id) => ({ id })),
        select: [
          'id',
          'username',
          'displayName',
          'avatarUrl',
          'isVerified',
        ],
      });
      const userMap = new Map(users.map((u) => [u.id, u]));
      const data = checkins.map((c) => ({
        ...c,
        user: userMap.get(c.userId) || null,
      }));
      return { data, total };
    }

    return { data: checkins, total };
  }

  async findRecent(
    page: number = 1,
    perPage: number = 20,
  ): Promise<{ data: CheckIn[]; total: number }> {
    const [data, total] = await this.checkinRepo.findAndCount({
      order: { createdAt: 'DESC' },
      skip: (page - 1) * perPage,
      take: perPage,
    });
    return { data, total };
  }
}
