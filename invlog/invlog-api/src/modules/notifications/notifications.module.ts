import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Notification, DeviceToken } from './entities/notification.entity';
import { User } from '../users/entities/user.entity';
import { NotificationsService } from './notifications.service';
import { NotificationsController } from './notifications.controller';
import { ApnsPushService } from './apns-push.service';

@Module({
  imports: [TypeOrmModule.forFeature([Notification, DeviceToken, User])],
  controllers: [NotificationsController],
  providers: [NotificationsService, ApnsPushService],
  exports: [NotificationsService],
})
export class NotificationsModule {}
