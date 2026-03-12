import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Restaurant, OperatingHours, MenuItem } from './entities/restaurant.entity';
import { CheckIn } from '../checkins/entities/checkin.entity';
import { User } from '../users/entities/user.entity';
import { Post, PostMedia } from '../posts/entities/post.entity';
import { RestaurantsService } from './restaurants.service';
import { RestaurantsController } from './restaurants.controller';

@Module({
  imports: [TypeOrmModule.forFeature([Restaurant, OperatingHours, MenuItem, CheckIn, User, Post, PostMedia])],
  controllers: [RestaurantsController],
  providers: [RestaurantsService],
  exports: [RestaurantsService],
})
export class RestaurantsModule {}
