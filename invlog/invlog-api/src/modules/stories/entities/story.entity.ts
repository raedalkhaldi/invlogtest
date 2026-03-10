import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  Index,
  Unique,
} from 'typeorm';
import type { User } from '../../users/entities/user.entity';

@Entity('stories')
export class Story {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Index()
  @Column({ name: 'author_id', type: 'uuid' })
  authorId: string;

  // Populated via batch hydration
  author?: User;

  @Column({ name: 'media_type', length: 10 })
  mediaType: 'image' | 'video';

  @Column({ length: 500 })
  url: string;

  @Column({ name: 'thumbnail_url', length: 500, nullable: true })
  thumbnailUrl: string;

  @Column({ length: 100, nullable: true })
  blurhash: string;

  @Column({
    name: 'duration_secs',
    type: 'decimal',
    precision: 8,
    scale: 2,
    nullable: true,
    transformer: {
      to: (v: number) => v,
      from: (v: string) => (v != null ? parseFloat(v) : null),
    },
  })
  durationSecs: number;

  @Column({ name: 'view_count', type: 'int', default: 0 })
  viewCount: number;

  @Index()
  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;

  @Column({ name: 'expires_at', type: 'timestamptz' })
  expiresAt: Date;

  // Populated dynamically
  isViewedByMe?: boolean;
}

@Entity('story_views')
@Unique(['storyId', 'userId'])
export class StoryView {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Index()
  @Column({ name: 'story_id', type: 'uuid' })
  storyId: string;

  @Column({ name: 'user_id', type: 'uuid' })
  userId: string;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;
}
