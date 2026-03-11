import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  Index,
} from 'typeorm';
import type { Restaurant } from '../../restaurants/entities/restaurant.entity';

export type StopCategory = 'restaurant' | 'cafe' | 'attraction' | 'hotel' | 'other';

@Entity('trip_stops')
export class TripStop {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Index()
  @Column({ name: 'trip_id', type: 'uuid' })
  tripId: string;

  @Column({ name: 'restaurant_id', type: 'uuid', nullable: true })
  restaurantId: string;

  // Populated via batch hydration
  restaurant?: Restaurant;

  @Column({ length: 255 })
  name: string;

  @Column({ length: 500, nullable: true })
  address: string;

  @Column({
    type: 'decimal',
    precision: 10,
    scale: 7,
    nullable: true,
    transformer: {
      to: (v: number) => v,
      from: (v: string) => (v != null ? parseFloat(v) : null),
    },
  })
  latitude: number;

  @Column({
    type: 'decimal',
    precision: 10,
    scale: 7,
    nullable: true,
    transformer: {
      to: (v: number) => v,
      from: (v: string) => (v != null ? parseFloat(v) : null),
    },
  })
  longitude: number;

  @Column({ name: 'day_number', type: 'int' })
  dayNumber: number;

  @Column({ name: 'sort_order', type: 'int', default: 0 })
  sortOrder: number;

  @Column({ type: 'text', nullable: true })
  notes: string;

  @Column({
    type: 'varchar',
    length: 20,
    default: 'restaurant',
  })
  category: StopCategory;

  @Column({
    name: 'estimated_duration',
    type: 'int',
    nullable: true,
  })
  estimatedDuration: number;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;
}
