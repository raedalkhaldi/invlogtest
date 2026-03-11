import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  Index,
} from 'typeorm';
import type { User } from '../../users/entities/user.entity';

export type TripVisibility = 'public' | 'private';
export type TripStatus = 'planning' | 'active' | 'completed';

@Entity('trips')
export class Trip {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ length: 255 })
  title: string;

  @Column({ type: 'text', nullable: true })
  description: string;

  @Column({ name: 'cover_image_url', length: 500, nullable: true })
  coverImageUrl: string;

  @Column({ name: 'start_date', type: 'date', nullable: true })
  startDate: string;

  @Column({ name: 'end_date', type: 'date', nullable: true })
  endDate: string;

  @Column({
    type: 'varchar',
    length: 10,
    default: 'public',
  })
  visibility: TripVisibility;

  @Column({
    type: 'varchar',
    length: 20,
    default: 'planning',
  })
  status: TripStatus;

  @Index()
  @Column({ name: 'owner_id', type: 'uuid' })
  ownerId: string;

  // Populated via batch hydration
  owner?: User;

  @Column({ name: 'like_count', type: 'int', default: 0 })
  likeCount: number;

  @Column({ name: 'save_count', type: 'int', default: 0 })
  saveCount: number;

  @Column({ name: 'stop_count', type: 'int', default: 0 })
  stopCount: number;

  @Index()
  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt: Date;

  // Populated via batch hydration
  stops?: TripStop[];
  collaborators?: TripCollaborator[];
}

// Re-export for convenience
import { TripStop } from './trip-stop.entity';
import { TripCollaborator } from './trip-collaborator.entity';
export { TripStop, TripCollaborator };
