import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  Index,
} from 'typeorm';
import { User } from '../../users/entities/user.entity';
import { Restaurant } from '../../restaurants/entities/restaurant.entity';

@Entity('checkins')
export class CheckIn {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  // Virtual properties populated by leftJoinAndMapOne in queries
  user?: User;
  restaurant?: Restaurant;

  @Index()
  @Column({ name: 'user_id' })
  userId: string;

  @Index()
  @Column({ name: 'restaurant_id' })
  restaurantId: string;

  @Column({ name: 'post_id', nullable: true })
  postId: string;

  @Column({ type: 'float', nullable: true })
  latitude: number;

  @Column({ type: 'float', nullable: true })
  longitude: number;

  @Index()
  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;
}
