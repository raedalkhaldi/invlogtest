import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import type { AppConfig } from '../../../config/configuration.js';
import type { JwtPayload } from '../../../common/decorators/current-user.decorator.js';

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy, 'jwt') {
  constructor(configService: ConfigService) {
    const jwtConfig = configService.get<AppConfig['jwt']>('jwt')!;

    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: jwtConfig.accessSecret,
    });
  }

  validate(payload: { sub: string; email: string; type: string }): JwtPayload {
    return {
      sub: payload.sub,
      email: payload.email,
      type: payload.type as JwtPayload['type'],
    };
  }
}
