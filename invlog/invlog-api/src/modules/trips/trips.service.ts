import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, In } from 'typeorm';
import { Trip } from './entities/trip.entity';
import { TripStop, type StopCategory } from './entities/trip-stop.entity';
import { TripCollaborator } from './entities/trip-collaborator.entity';
import { User } from '../users/entities/user.entity';
import { Restaurant } from '../restaurants/entities/restaurant.entity';
import { CreateTripDto } from './dto/create-trip.dto';
import { UpdateTripDto } from './dto/update-trip.dto';
import { AddStopDto } from './dto/add-stop.dto';
import { UpdateStopDto } from './dto/update-stop.dto';
import { InviteCollaboratorDto } from './dto/invite-collaborator.dto';

@Injectable()
export class TripsService {
  constructor(
    @InjectRepository(Trip)
    private readonly tripRepo: Repository<Trip>,
    @InjectRepository(TripStop)
    private readonly stopRepo: Repository<TripStop>,
    @InjectRepository(TripCollaborator)
    private readonly collaboratorRepo: Repository<TripCollaborator>,
    @InjectRepository(User)
    private readonly userRepo: Repository<User>,
    @InjectRepository(Restaurant)
    private readonly restaurantRepo: Repository<Restaurant>,
  ) {}

  /**
   * Hydrate trips with owner, stops, and collaborators using batch queries.
   */
  private async hydrateTrips(
    trips: Trip[],
    options: { stops?: boolean; collaborators?: boolean } = {},
  ): Promise<Trip[]> {
    if (!trips.length) return trips;

    const tripIds = trips.map((t) => t.id);

    // Batch-fetch owners
    const ownerIds = [...new Set(trips.map((t) => t.ownerId).filter(Boolean))];
    if (ownerIds.length) {
      const owners = await this.userRepo
        .createQueryBuilder('u')
        .select([
          'u.id',
          'u.username',
          'u.displayName',
          'u.avatarUrl',
          'u.isVerified',
        ])
        .where('u.id IN (:...ids)', { ids: ownerIds })
        .getMany();
      const ownerMap = new Map(owners.map((o) => [o.id, o]));
      for (const trip of trips) {
        trip.owner = ownerMap.get(trip.ownerId);
      }
    }

    // Batch-fetch stops
    if (options.stops) {
      const allStops = await this.stopRepo.find({
        where: { tripId: In(tripIds) },
        order: { dayNumber: 'ASC', sortOrder: 'ASC' },
      });

      // Batch-fetch restaurants for stops
      const restaurantIds = [
        ...new Set(allStops.map((s) => s.restaurantId).filter(Boolean)),
      ];
      if (restaurantIds.length) {
        const restaurants = await this.restaurantRepo.find({
          where: { id: In(restaurantIds) },
        });
        const restMap = new Map(restaurants.map((r) => [r.id, r]));
        for (const stop of allStops) {
          if (stop.restaurantId) {
            stop.restaurant = restMap.get(stop.restaurantId);
          }
        }
      }

      const stopsMap = new Map<string, TripStop[]>();
      for (const stop of allStops) {
        const list = stopsMap.get(stop.tripId) ?? [];
        list.push(stop);
        stopsMap.set(stop.tripId, list);
      }
      for (const trip of trips) {
        trip.stops = stopsMap.get(trip.id) ?? [];
      }
    }

    // Batch-fetch collaborators
    if (options.collaborators) {
      const allCollabs = await this.collaboratorRepo.find({
        where: { tripId: In(tripIds) },
        order: { createdAt: 'ASC' },
      });

      // Batch-fetch collaborator users
      const collabUserIds = [
        ...new Set(allCollabs.map((c) => c.userId).filter(Boolean)),
      ];
      if (collabUserIds.length) {
        const users = await this.userRepo
          .createQueryBuilder('u')
          .select([
            'u.id',
            'u.username',
            'u.displayName',
            'u.avatarUrl',
            'u.isVerified',
          ])
          .where('u.id IN (:...ids)', { ids: collabUserIds })
          .getMany();
        const userMap = new Map(users.map((u) => [u.id, u]));
        for (const collab of allCollabs) {
          collab.user = userMap.get(collab.userId);
        }
      }

      const collabMap = new Map<string, TripCollaborator[]>();
      for (const collab of allCollabs) {
        const list = collabMap.get(collab.tripId) ?? [];
        list.push(collab);
        collabMap.set(collab.tripId, list);
      }
      for (const trip of trips) {
        trip.collaborators = collabMap.get(trip.id) ?? [];
      }
    }

    return trips;
  }

  /**
   * Check if user has access to a trip (owner or collaborator).
   * Returns the role or null if no access.
   */
  private async getUserRole(
    tripId: string,
    userId: string,
  ): Promise<'owner' | 'editor' | 'viewer' | null> {
    const trip = await this.tripRepo.findOne({ where: { id: tripId } });
    if (!trip) return null;
    if (trip.ownerId === userId) return 'owner';

    const collab = await this.collaboratorRepo.findOne({
      where: { tripId, userId },
    });
    if (collab) return collab.role;

    return null;
  }

  /**
   * Assert user can edit trip (owner or editor).
   */
  private async assertCanEdit(tripId: string, userId: string): Promise<Trip> {
    const trip = await this.tripRepo.findOne({ where: { id: tripId } });
    if (!trip) throw new NotFoundException('Trip not found');

    if (trip.ownerId === userId) return trip;

    const collab = await this.collaboratorRepo.findOne({
      where: { tripId, userId },
    });
    if (collab && collab.role === 'editor') return trip;

    throw new ForbiddenException('You do not have edit access to this trip');
  }

  /**
   * Assert user is the trip owner.
   */
  private async assertIsOwner(tripId: string, userId: string): Promise<Trip> {
    const trip = await this.tripRepo.findOne({ where: { id: tripId } });
    if (!trip) throw new NotFoundException('Trip not found');
    if (trip.ownerId !== userId) {
      throw new ForbiddenException('Only the trip owner can perform this action');
    }
    return trip;
  }

  async create(userId: string, dto: CreateTripDto): Promise<Trip> {
    const trip = this.tripRepo.create({
      ownerId: userId,
      title: dto.title,
      description: dto.description,
      coverImageUrl: dto.coverImageUrl,
      startDate: dto.startDate,
      endDate: dto.endDate,
      visibility: dto.visibility ?? 'public',
    });

    const saved = await this.tripRepo.save(trip);
    return this.findOne(saved.id, userId);
  }

  async findAll(
    userId: string,
    cursor?: string,
    limit: number = 20,
  ): Promise<{ data: Trip[]; nextCursor: string | null }> {
    // Get trip IDs where user is a collaborator
    const collabs = await this.collaboratorRepo.find({
      where: { userId },
      select: ['tripId'],
    });
    const collabTripIds = collabs.map((c) => c.tripId);

    const qb = this.tripRepo
      .createQueryBuilder('trip')
      .where(
        '(trip.owner_id = :userId' +
          (collabTripIds.length
            ? ' OR trip.id IN (:...collabTripIds))'
            : ')'),
        { userId, ...(collabTripIds.length ? { collabTripIds } : {}) },
      )
      .orderBy('trip.created_at', 'DESC')
      .take(limit + 1);

    if (cursor) {
      const cursorDate = new Date(
        Buffer.from(cursor, 'base64').toString('utf-8'),
      );
      qb.andWhere('trip.created_at < :cursor', { cursor: cursorDate });
    }

    const trips = await qb.getMany();
    await this.hydrateTrips(trips);

    let nextCursor: string | null = null;
    if (trips.length > limit) {
      trips.pop();
      const last = trips[trips.length - 1];
      nextCursor = Buffer.from(last.createdAt.toISOString()).toString('base64');
    }

    return { data: trips, nextCursor };
  }

  async findPublic(
    cursor?: string,
    limit: number = 20,
  ): Promise<{ data: Trip[]; nextCursor: string | null }> {
    const qb = this.tripRepo
      .createQueryBuilder('trip')
      .where('trip.visibility = :visibility', { visibility: 'public' })
      .orderBy('trip.created_at', 'DESC')
      .take(limit + 1);

    if (cursor) {
      const cursorDate = new Date(
        Buffer.from(cursor, 'base64').toString('utf-8'),
      );
      qb.andWhere('trip.created_at < :cursor', { cursor: cursorDate });
    }

    const trips = await qb.getMany();
    await this.hydrateTrips(trips);

    let nextCursor: string | null = null;
    if (trips.length > limit) {
      trips.pop();
      const last = trips[trips.length - 1];
      nextCursor = Buffer.from(last.createdAt.toISOString()).toString('base64');
    }

    return { data: trips, nextCursor };
  }

  async findOne(tripId: string, userId: string): Promise<Trip> {
    const trip = await this.tripRepo.findOne({ where: { id: tripId } });
    if (!trip) throw new NotFoundException('Trip not found');

    // Check access: public trips are visible to all, private trips require membership
    if (trip.visibility === 'private') {
      const role = await this.getUserRole(tripId, userId);
      if (!role) {
        throw new ForbiddenException('You do not have access to this trip');
      }
    }

    await this.hydrateTrips([trip], { stops: true, collaborators: true });
    return trip;
  }

  async update(
    tripId: string,
    userId: string,
    dto: UpdateTripDto,
  ): Promise<Trip> {
    const trip = await this.assertCanEdit(tripId, userId);
    Object.assign(trip, dto);
    await this.tripRepo.save(trip);
    return this.findOne(tripId, userId);
  }

  async delete(tripId: string, userId: string): Promise<void> {
    await this.assertIsOwner(tripId, userId);
    await this.tripRepo.delete(tripId);
  }

  async addStop(
    tripId: string,
    userId: string,
    dto: AddStopDto,
  ): Promise<TripStop> {
    await this.assertCanEdit(tripId, userId);

    // Auto-assign sortOrder if not provided
    let sortOrder = dto.sortOrder;
    if (sortOrder == null) {
      const maxStop = await this.stopRepo
        .createQueryBuilder('stop')
        .select('MAX(stop.sort_order)', 'maxOrder')
        .where('stop.trip_id = :tripId AND stop.day_number = :dayNumber', {
          tripId,
          dayNumber: dto.dayNumber,
        })
        .getRawOne();
      sortOrder = (maxStop?.maxOrder ?? -1) + 1;
    }

    const stop = this.stopRepo.create({
      tripId,
      name: dto.name,
      restaurantId: dto.restaurantId,
      address: dto.address,
      latitude: dto.latitude,
      longitude: dto.longitude,
      dayNumber: dto.dayNumber,
      sortOrder,
      notes: dto.notes,
      category: (dto.category ?? 'restaurant') as StopCategory,
      estimatedDuration: dto.estimatedDuration,
      startTime: dto.startTime,
      endTime: dto.endTime,
    });

    const saved = await this.stopRepo.save(stop);

    // Increment stop count
    await this.tripRepo
      .createQueryBuilder()
      .update(Trip)
      .set({ stopCount: () => '"stop_count" + 1' })
      .where('id = :id', { id: tripId })
      .execute();

    return saved;
  }

  async updateStop(
    stopId: string,
    userId: string,
    dto: UpdateStopDto,
  ): Promise<TripStop> {
    const stop = await this.stopRepo.findOne({ where: { id: stopId } });
    if (!stop) throw new NotFoundException('Stop not found');

    await this.assertCanEdit(stop.tripId, userId);

    Object.assign(stop, dto);
    return this.stopRepo.save(stop);
  }

  async removeStop(stopId: string, userId: string): Promise<void> {
    const stop = await this.stopRepo.findOne({ where: { id: stopId } });
    if (!stop) throw new NotFoundException('Stop not found');

    await this.assertCanEdit(stop.tripId, userId);
    await this.stopRepo.delete(stopId);

    // Decrement stop count
    await this.tripRepo
      .createQueryBuilder()
      .update(Trip)
      .set({ stopCount: () => 'GREATEST("stop_count" - 1, 0)' })
      .where('id = :id', { id: stop.tripId })
      .execute();
  }

  async reorderStops(
    tripId: string,
    userId: string,
    stopIds: string[],
  ): Promise<TripStop[]> {
    await this.assertCanEdit(tripId, userId);

    // Verify all stops belong to this trip
    const stops = await this.stopRepo.find({
      where: { tripId, id: In(stopIds) },
    });

    if (stops.length !== stopIds.length) {
      throw new BadRequestException(
        'Some stop IDs are invalid or do not belong to this trip',
      );
    }

    // Update sort order based on position in the array
    for (let i = 0; i < stopIds.length; i++) {
      await this.stopRepo
        .createQueryBuilder()
        .update(TripStop)
        .set({ sortOrder: i })
        .where('id = :id', { id: stopIds[i] })
        .execute();
    }

    return this.stopRepo.find({
      where: { tripId },
      order: { dayNumber: 'ASC', sortOrder: 'ASC' },
    });
  }

  async inviteCollaborator(
    tripId: string,
    userId: string,
    dto: InviteCollaboratorDto,
  ): Promise<TripCollaborator> {
    await this.assertIsOwner(tripId, userId);

    if (dto.userId === userId) {
      throw new BadRequestException('You cannot invite yourself');
    }

    // Check user exists
    const targetUser = await this.userRepo.findOne({
      where: { id: dto.userId },
    });
    if (!targetUser) throw new NotFoundException('User not found');

    // Check for existing collaborator
    const existing = await this.collaboratorRepo.findOne({
      where: { tripId, userId: dto.userId },
    });
    if (existing) {
      throw new BadRequestException('User is already a collaborator');
    }

    const collab = this.collaboratorRepo.create({
      tripId,
      userId: dto.userId,
      role: dto.role ?? 'editor',
    });

    const saved = await this.collaboratorRepo.save(collab);

    // Hydrate user on the collaborator
    saved.user = targetUser;

    return saved;
  }

  async removeCollaborator(
    tripId: string,
    userId: string,
    collaboratorUserId: string,
  ): Promise<void> {
    await this.assertIsOwner(tripId, userId);

    const collab = await this.collaboratorRepo.findOne({
      where: { tripId, userId: collaboratorUserId },
    });
    if (!collab) throw new NotFoundException('Collaborator not found');

    await this.collaboratorRepo.delete(collab.id);
  }

  async cloneTrip(tripId: string, userId: string): Promise<Trip> {
    const original = await this.tripRepo.findOne({ where: { id: tripId } });
    if (!original) throw new NotFoundException('Trip not found');

    // Only allow cloning public trips or trips user has access to
    if (original.visibility === 'private') {
      const role = await this.getUserRole(tripId, userId);
      if (!role) {
        throw new ForbiddenException('You do not have access to this trip');
      }
    }

    // Create new trip as a clone
    const cloned = this.tripRepo.create({
      ownerId: userId,
      title: `${original.title} (copy)`,
      description: original.description,
      coverImageUrl: original.coverImageUrl,
      startDate: original.startDate,
      endDate: original.endDate,
      visibility: 'private',
      status: 'planning',
    });

    const savedTrip = await this.tripRepo.save(cloned);

    // Clone stops
    const originalStops = await this.stopRepo.find({
      where: { tripId },
      order: { dayNumber: 'ASC', sortOrder: 'ASC' },
    });

    if (originalStops.length) {
      const clonedStops = originalStops.map((stop) =>
        this.stopRepo.create({
          tripId: savedTrip.id,
          restaurantId: stop.restaurantId,
          name: stop.name,
          address: stop.address,
          latitude: stop.latitude,
          longitude: stop.longitude,
          dayNumber: stop.dayNumber,
          sortOrder: stop.sortOrder,
          notes: stop.notes,
          category: stop.category,
          estimatedDuration: stop.estimatedDuration,
        }),
      );

      await this.stopRepo.save(clonedStops);

      // Set stop count
      await this.tripRepo
        .createQueryBuilder()
        .update(Trip)
        .set({ stopCount: clonedStops.length })
        .where('id = :id', { id: savedTrip.id })
        .execute();
    }

    return this.findOne(savedTrip.id, userId);
  }

  async findByUser(
    username: string,
    cursor?: string,
    limit: number = 20,
  ): Promise<{ data: Trip[]; nextCursor: string | null }> {
    const user = await this.userRepo.findOne({ where: { username } });
    if (!user) throw new NotFoundException('User not found');

    const qb = this.tripRepo
      .createQueryBuilder('trip')
      .where('trip.owner_id = :ownerId', { ownerId: user.id })
      .andWhere('trip.visibility = :visibility', { visibility: 'public' })
      .orderBy('trip.created_at', 'DESC')
      .take(limit + 1);

    if (cursor) {
      const cursorDate = new Date(
        Buffer.from(cursor, 'base64').toString('utf-8'),
      );
      qb.andWhere('trip.created_at < :cursor', { cursor: cursorDate });
    }

    const trips = await qb.getMany();
    await this.hydrateTrips(trips);

    let nextCursor: string | null = null;
    if (trips.length > limit) {
      trips.pop();
      const last = trips[trips.length - 1];
      nextCursor = Buffer.from(last.createdAt.toISOString()).toString('base64');
    }

    return { data: trips, nextCursor };
  }
}
