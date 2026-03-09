import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  Index,
  Unique,
} from 'typeorm';

@Entity('follows')
@Unique(['followerId', 'targetType', 'targetId'])
export class Follow {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Index()
  @Column({ name: 'follower_id' })
  followerId: string;

  @Index()
  @Column({ name: 'target_type', length: 15 })
  targetType: 'user' | 'restaurant';

  @Column({ name: 'target_id' })
  targetId: string;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;
}
