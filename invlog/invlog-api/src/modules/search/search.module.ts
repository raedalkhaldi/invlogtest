import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { User } from '../users/entities/user.entity';
import { Restaurant } from '../restaurants/entities/restaurant.entity';
import { Post } from '../posts/entities/post.entity';
import { Follow } from '../follows/entities/follow.entity';
import { SearchService } from './search.service';
import { SearchController } from './search.controller';

@Module({
  imports: [TypeOrmModule.forFeature([User, Restaurant, Post, Follow])],
  controllers: [SearchController],
  providers: [SearchService],
})
export class SearchModule {}
