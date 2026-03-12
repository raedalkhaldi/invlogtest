import {
  Injectable,
  Logger,
  OnModuleInit,
  OnModuleDestroy,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as apn from '@parse/node-apn';

@Injectable()
export class ApnsPushService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(ApnsPushService.name);
  private provider: apn.Provider | null = null;
  private bundleId: string;

  constructor(private readonly configService: ConfigService) {}

  onModuleInit() {
    const keyId = this.configService.get<string>('apns.keyId');
    const teamId = this.configService.get<string>('apns.teamId');
    const keyContent = this.configService.get<string>('apns.keyContent');
    this.bundleId =
      this.configService.get<string>('apns.bundleId') ?? 'com.invlog.app';
    const production =
      this.configService.get<boolean>('apns.production') ?? false;

    if (!keyId || !teamId || !keyContent) {
      this.logger.warn(
        'APNS credentials not configured — push notifications disabled',
      );
      return;
    }

    this.provider = new apn.Provider({
      token: {
        key: keyContent,
        keyId,
        teamId,
      },
      production,
    });

    this.logger.log(`APNS provider initialized (production=${production})`);
  }

  onModuleDestroy() {
    if (this.provider) {
      this.provider.shutdown();
    }
  }

  async sendPush(
    deviceTokens: string[],
    payload: {
      title: string;
      body: string;
      badge?: number;
      data?: Record<string, string>;
    },
  ): Promise<{ sent: number; failed: number; invalidTokens: string[] }> {
    if (!this.provider) {
      this.logger.debug('APNS provider not configured — skipping push');
      return { sent: 0, failed: 0, invalidTokens: [] };
    }

    if (deviceTokens.length === 0) {
      return { sent: 0, failed: 0, invalidTokens: [] };
    }

    const notification = new apn.Notification();
    notification.alert = { title: payload.title, body: payload.body };
    notification.topic = this.bundleId;
    notification.sound = 'default';
    notification.badge = payload.badge ?? 0;
    notification.pushType = 'alert';

    if (payload.data) {
      notification.payload = payload.data;
    }

    try {
      const result = await this.provider.send(notification, deviceTokens);

      const invalidTokens = result.failed
        .filter(
          (f) =>
            f.status === 410 ||
            f.response?.reason === 'Unregistered' ||
            f.response?.reason === 'BadDeviceToken',
        )
        .map((f) => f.device);

      if (invalidTokens.length > 0) {
        this.logger.warn(
          `${invalidTokens.length} invalid device tokens detected`,
        );
      }

      if (result.sent.length > 0) {
        this.logger.debug(
          `Push sent to ${result.sent.length} device(s), ${result.failed.length} failed`,
        );
      }

      return {
        sent: result.sent.length,
        failed: result.failed.length,
        invalidTokens,
      };
    } catch (error) {
      this.logger.error(`Failed to send push notification: ${error.message}`);
      return { sent: 0, failed: deviceTokens.length, invalidTokens: [] };
    }
  }
}
