import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  Index,
  Unique,
} from 'typeorm';
import type { User } from '../../users/entities/user.entity';

export type CollaboratorRole = 'editor' | 'viewer';

@Entity('trip_collaborators')
@Unique(['tripId', 'userId'])
export class TripCollaborator {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Index()
  @Column({ name: 'trip_id', type: 'uuid' })
  tripId: string;

  @Column({ name: 'user_id', type: 'uuid' })
  userId: string;

  // Populated via batch hydration
  user?: User;

  @Column({
    type: 'varchar',
    length: 10,
    default: 'editor',
  })
  role: CollaboratorRole;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;
}
