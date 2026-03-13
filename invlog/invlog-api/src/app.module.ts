import { Module } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { BullModule } from '@nestjs/bullmq';
import { CacheModule } from '@nestjs/cache-manager';
import { ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';
import configuration from './config/configuration.js';
import databaseConfig from './config/database.config.js';
import storageConfig from './config/storage.config.js';
import { JwtAuthGuard } from './common/guards/jwt-auth.guard.js';
import { HealthModule } from './modules/health/health.module.js';
import { AuthModule } from './modules/auth/auth.module';
import { UsersModule } from './modules/users/users.module';
import { PostsModule } from './modules/posts/posts.module';
import { CommentsModule } from './modules/comments/comments.module';
import { LikesModule } from './modules/likes/likes.module';
import { FollowsModule } from './modules/follows/follows.module';
import { CheckInsModule } from './modules/checkins/checkins.module';
import { RestaurantsModule } from './modules/restaurants/restaurants.module';
import { FeedModule } from './modules/feed/feed.module';
import { NotificationsModule } from './modules/notifications/notifications.module';
import { MediaModule } from './modules/media/media.module';
import { SearchModule } from './modules/search/search.module';
import { BookmarksModule } from './modules/bookmarks/bookmarks.module';
import { StoriesModule } from './modules/stories/stories.module';
import { MessagesModule } from './modules/messages/messages.module';
import { TripsModule } from './modules/trips/trips.module';
import { BlocksModule } from './modules/blocks/blocks.module';
import type { TypeOrmModuleOptions } from '@nestjs/typeorm';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      load: [configuration, databaseConfig, storageConfig],
    }),
    TypeOrmModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (configService: ConfigService) =>
        configService.get<TypeOrmModuleOptions>('database')!,
    }),
    BullModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (configService: ConfigService) => {
        const redisUrl = configService.get<string | null>('redis.url');
        if (redisUrl) {
          return { connection: { url: redisUrl } };
        }
        return {
          connection: {
            host: configService.get('redis.host'),
            port: configService.get('redis.port'),
          },
        };
      },
    }),
    CacheModule.registerAsync({
      isGlobal: true,
      inject: [ConfigService],
      useFactory: async (configService: ConfigService) => {
        const redisUrl = configService.get<string | null>('redis.url');
        if (redisUrl) {
          const { redisStore } = await import('cache-manager-ioredis-yet');
          return {
            store: redisStore,
            url: redisUrl,
            ttl: 300000, // 5 minutes default TTL (ms)
          };
        }
        // In-memory cache for local dev
        return { ttl: 300000 };
      },
    }),
    ThrottlerModule.forRoot([
      {
        name: 'default',
        ttl: 60000,
        limit: 600,
      },
      {
        name: 'auth',
        ttl: 60000,
        limit: 10,
      },
    ]),
    HealthModule,
    AuthModule,
    UsersModule,
    PostsModule,
    CommentsModule,
    LikesModule,
    FollowsModule,
    CheckInsModule,
    RestaurantsModule,
    FeedModule,
    NotificationsModule,
    MediaModule,
    SearchModule,
    BookmarksModule,
    StoriesModule,
    MessagesModule,
    TripsModule,
    BlocksModule,
  ],
  providers: [
    {
      provide: APP_GUARD,
      useClass: JwtAuthGuard,
    },
    {
      provide: APP_GUARD,
      useClass: ThrottlerGuard,
    },
  ],
})
export class AppModule {}
