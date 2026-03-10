import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  DeleteDateColumn,
  ManyToOne,
  OneToMany,
  JoinColumn,
  Index,
} from 'typeorm';
import type { User } from '../../users/entities/user.entity';
import type { Restaurant } from '../../restaurants/entities/restaurant.entity';

@Entity('posts')
export class Post {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'author_id', type: 'uuid' })
  authorId: string;

  @Column({ name: 'restaurant_id', type: 'uuid', nullable: true })
  restaurantId: string;

  // Populated via leftJoinAndMapOne in queries (no @ManyToOne to avoid synchronize conflicts)
  author?: User;
  restaurant?: Restaurant;

  @Column({ type: 'text', nullable: true })
  content: string;

  @Column({ type: 'smallint', nullable: true })
  rating: number;

  @Column({ type: 'float', nullable: true })
  latitude: number;

  @Column({ type: 'float', nullable: true })
  longitude: number;

  @Column({ name: 'location_name', length: 255, nullable: true })
  locationName: string;

  @Column({ name: 'location_address', length: 500, nullable: true })
  locationAddress: string;

  @Column({ name: 'like_count', type: 'int', default: 0 })
  likeCount: number;

  @Column({ name: 'comment_count', type: 'int', default: 0 })
  commentCount: number;

  @Column({ name: 'is_public', default: true })
  isPublic: boolean;

  @Index()
  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt: Date;

  @DeleteDateColumn({ name: 'deleted_at', type: 'timestamptz' })
  deletedAt: Date;

  @OneToMany(() => PostMedia, (media) => media.post, { cascade: true, eager: true })
  media: PostMedia[];
}

@Entity('post_media')
export class PostMedia {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Index()
  @Column({ name: 'post_id', nullable: true })
  postId: string | null;

  @ManyToOne(() => Post, (post) => post.media, {
    onDelete: 'CASCADE',
    nullable: true,
  })
  @JoinColumn({ name: 'post_id' })
  post: Post;

  @Column({ name: 'uploader_id', nullable: true })
  uploaderId: string;

  @Column({ name: 'media_type', length: 10 })
  mediaType: 'image' | 'video';

  @Column({ length: 500 })
  url: string;

  @Column({ name: 'medium_url', length: 500, nullable: true })
  mediumUrl: string;

  @Column({ name: 'thumbnail_url', length: 500, nullable: true })
  thumbnailUrl: string;

  @Column({ type: 'int', nullable: true })
  width: number;

  @Column({ type: 'int', nullable: true })
  height: number;

  @Column({ name: 'duration_secs', type: 'decimal', precision: 8, scale: 2, nullable: true })
  durationSecs: number;

  @Column({ name: 'sort_order', type: 'smallint', default: 0 })
  sortOrder: number;

  @Column({ length: 100, nullable: true })
  blurhash: string;

  @Column({
    name: 'processing_status',
    length: 20,
    default: 'pending',
  })
  processingStatus: 'pending' | 'processing' | 'ready' | 'failed';

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;
}
