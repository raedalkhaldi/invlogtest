import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  ConflictException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Restaurant, OperatingHours, MenuItem } from './entities/restaurant.entity';
import { CheckIn } from '../checkins/entities/checkin.entity';
import { User } from '../users/entities/user.entity';
import {
  CreateRestaurantDto,
  UpdateRestaurantDto,
  CreateMenuItemDto,
  NearbyQueryDto,
} from './dto/create-restaurant.dto';

@Injectable()
export class RestaurantsService {
  constructor(
    @InjectRepository(Restaurant)
    private readonly restaurantRepo: Repository<Restaurant>,
    @InjectRepository(OperatingHours)
    private readonly operatingHoursRepo: Repository<OperatingHours>,
    @InjectRepository(MenuItem)
    private readonly menuItemRepo: Repository<MenuItem>,
    @InjectRepository(CheckIn)
    private readonly checkinRepo: Repository<CheckIn>,
    @InjectRepository(User)
    private readonly userRepo: Repository<User>,
  ) {}

  private generateSlug(name: string): string {
    return name
      .toLowerCase()
      .replace(/[^a-z0-9\s-]/g, '')
      .replace(/\s+/g, '-')
      .replace(/-+/g, '-')
      .trim();
  }

  async create(ownerId: string, dto: CreateRestaurantDto): Promise<Restaurant> {
    let slug = this.generateSlug(dto.name);

    // Ensure slug uniqueness
    const existing = await this.restaurantRepo.findOne({ where: { slug } });
    if (existing) {
      slug = `${slug}-${Date.now().toString(36)}`;
    }

    const restaurant = this.restaurantRepo.create({
      ownerId,
      name: dto.name,
      slug,
      description: dto.description,
      cuisineType: dto.cuisineType,
      phone: dto.phone,
      email: dto.email,
      website: dto.website,
      addressLine1: dto.addressLine1,
      addressLine2: dto.addressLine2,
      city: dto.city,
      state: dto.state,
      country: dto.country,
      postalCode: dto.postalCode,
      priceRange: dto.priceRange,
      latitude: dto.latitude,
      longitude: dto.longitude,
    });

    return this.restaurantRepo.save(restaurant);
  }

  async findById(id: string): Promise<Restaurant> {
    const restaurant = await this.restaurantRepo.findOne({ where: { id } });
    if (!restaurant) {
      throw new NotFoundException('Restaurant not found');
    }
    return restaurant;
  }

  async findBySlug(slug: string): Promise<Restaurant> {
    const restaurant = await this.restaurantRepo.findOne({ where: { slug } });
    if (!restaurant) {
      throw new NotFoundException('Restaurant not found');
    }
    return restaurant;
  }

  async update(
    id: string,
    userId: string,
    dto: UpdateRestaurantDto,
  ): Promise<Restaurant> {
    const restaurant = await this.findById(id);
    if (restaurant.ownerId !== userId) {
      throw new ForbiddenException(
        'You can only update your own restaurants',
      );
    }

    Object.assign(restaurant, dto);

    if (dto.name) {
      let slug = this.generateSlug(dto.name);
      const existing = await this.restaurantRepo.findOne({ where: { slug } });
      if (existing && existing.id !== id) {
        slug = `${slug}-${Date.now().toString(36)}`;
      }
      restaurant.slug = slug;
    }

    return this.restaurantRepo.save(restaurant);
  }

  async findNearby(
    query: NearbyQueryDto,
  ): Promise<(Restaurant & { distance: number })[]> {
    const radiusKm = query.radiusKm ?? 5;
    const limit = query.limit ?? 20;

    // Approximate bounding box for first-pass filter: 1 degree latitude ~ 111 km
    const latDelta = radiusKm / 111;
    // 1 degree longitude varies by latitude
    const lngDelta = radiusKm / (111 * Math.cos((query.lat * Math.PI) / 180));

    const minLat = query.lat - latDelta;
    const maxLat = query.lat + latDelta;
    const minLng = query.lng - lngDelta;
    const maxLng = query.lng + lngDelta;

    const haversine =
      `(6371 * acos(` +
      `cos(radians(:lat)) * cos(radians(restaurant.latitude)) * ` +
      `cos(radians(restaurant.longitude) - radians(:lng)) + ` +
      `sin(radians(:lat)) * sin(radians(restaurant.latitude))` +
      `))`;

    const results = await this.restaurantRepo
      .createQueryBuilder('restaurant')
      .addSelect(haversine, 'distance')
      .where('restaurant.latitude BETWEEN :minLat AND :maxLat', { minLat, maxLat })
      .andWhere('restaurant.longitude BETWEEN :minLng AND :maxLng', { minLng, maxLng })
      .andWhere('restaurant.is_active = true')
      .having(`${haversine} <= :radiusKm`)
      .setParameters({ lat: query.lat, lng: query.lng, radiusKm })
      .groupBy('restaurant.id')
      .orderBy('distance', 'ASC')
      .limit(limit)
      .getRawAndEntities();

    // Merge the distance from raw results into the entities
    return results.entities.map((entity, i) => {
      const raw = results.raw[i];
      return Object.assign(entity, {
        distance: parseFloat(raw.distance),
      });
    });
  }

  // Menu item CRUD

  async getMenuItems(restaurantId: string): Promise<MenuItem[]> {
    await this.findById(restaurantId);
    return this.menuItemRepo.find({
      where: { restaurantId },
      order: { sortOrder: 'ASC', createdAt: 'ASC' },
    });
  }

  async createMenuItem(
    restaurantId: string,
    userId: string,
    dto: CreateMenuItemDto,
  ): Promise<MenuItem> {
    const restaurant = await this.findById(restaurantId);
    if (restaurant.ownerId !== userId) {
      throw new ForbiddenException(
        'You can only manage menu items for your own restaurants',
      );
    }

    const item = this.menuItemRepo.create({
      restaurantId,
      ...dto,
    });

    return this.menuItemRepo.save(item);
  }

  async updateMenuItem(
    restaurantId: string,
    itemId: string,
    userId: string,
    dto: CreateMenuItemDto,
  ): Promise<MenuItem> {
    const restaurant = await this.findById(restaurantId);
    if (restaurant.ownerId !== userId) {
      throw new ForbiddenException(
        'You can only manage menu items for your own restaurants',
      );
    }

    const item = await this.menuItemRepo.findOne({
      where: { id: itemId, restaurantId },
    });
    if (!item) {
      throw new NotFoundException('Menu item not found');
    }

    Object.assign(item, dto);
    return this.menuItemRepo.save(item);
  }

  async deleteMenuItem(
    restaurantId: string,
    itemId: string,
    userId: string,
  ): Promise<void> {
    const restaurant = await this.findById(restaurantId);
    if (restaurant.ownerId !== userId) {
      throw new ForbiddenException(
        'You can only manage menu items for your own restaurants',
      );
    }

    const item = await this.menuItemRepo.findOne({
      where: { id: itemId, restaurantId },
    });
    if (!item) {
      throw new NotFoundException('Menu item not found');
    }

    await this.menuItemRepo.remove(item);
  }

  // Operating hours

  async getOperatingHours(restaurantId: string): Promise<OperatingHours[]> {
    await this.findById(restaurantId);
    return this.operatingHoursRepo.find({
      where: { restaurantId },
      order: { dayOfWeek: 'ASC' },
    });
  }

  // Check-ins for a restaurant

  async getCheckins(
    restaurantId: string,
    page: number = 1,
    perPage: number = 20,
  ): Promise<{ data: any[]; total: number }> {
    await this.findById(restaurantId);
    const [checkins, total] = await this.checkinRepo.findAndCount({
      where: { restaurantId },
      order: { createdAt: 'DESC' },
      skip: (page - 1) * perPage,
      take: perPage,
    });

    // Hydrate users
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
}
