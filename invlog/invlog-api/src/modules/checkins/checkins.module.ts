import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { CheckIn } from './entities/checkin.entity';
import { Restaurant } from '../restaurants/entities/restaurant.entity';
import { User } from '../users/entities/user.entity';
import { CheckInsService } from './checkins.service';
import { CheckInsController } from './checkins.controller';

@Module({
  imports: [TypeOrmModule.forFeature([CheckIn, Restaurant, User])],
  controllers: [CheckInsController],
  providers: [CheckInsService],
  exports: [CheckInsService],
})
export class CheckInsModule {}
