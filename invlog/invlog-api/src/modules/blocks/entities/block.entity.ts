import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  Unique,
  Index,
} from 'typeorm';

@Entity('blocks')
@Unique(['blockerId', 'blockedUserId'])
export class Block {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Index()
  @Column({ name: 'blocker_id', type: 'uuid' })
  blockerId: string;

  @Index()
  @Column({ name: 'blocked_user_id', type: 'uuid' })
  blockedUserId: string;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;
}
