import {
  Injectable,
  UnauthorizedException,
  ConflictException,
  BadRequestException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { InjectRepository } from '@nestjs/typeorm';
import { IsNull, Repository } from 'typeorm';
import * as bcrypt from 'bcrypt';
import { createHash, randomUUID } from 'crypto';
import { UsersService } from '../users/users.service.js';
import { RefreshToken } from './entities/refresh-token.entity.js';
import { UserSocialAccount } from './entities/user-social-account.entity.js';
import type { RegisterDto } from './dto/register.dto.js';
import type { LoginDto } from './dto/login.dto.js';
import type { SocialLoginDto } from './dto/social-login.dto.js';
import type { User } from '../users/entities/user.entity.js';
import type { AppConfig } from '../../config/configuration.js';
import type { StringValue } from 'ms';

export interface TokenResponse {
  accessToken: string;
  refreshToken: string;
  expiresIn: number;
  user: {
    id: string;
    email: string;
    username: string;
    displayName: string | null;
    bio: string | null;
    avatarUrl: string | null;
    isVerified: boolean;
    isPrivate: boolean;
    followerCount: number;
    followingCount: number;
    postCount: number;
  };
}

@Injectable()
export class AuthService {
  constructor(
    private readonly usersService: UsersService,
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
    @InjectRepository(RefreshToken)
    private readonly refreshTokenRepository: Repository<RefreshToken>,
    @InjectRepository(UserSocialAccount)
    private readonly socialAccountRepository: Repository<UserSocialAccount>,
  ) {}

  async register(dto: RegisterDto): Promise<TokenResponse> {
    const existingByEmail = await this.usersService.findByEmail(dto.email);
    if (existingByEmail) {
      throw new ConflictException('Email already in use');
    }

    const existingByUsername = await this.usersService.findByUsername(dto.username);
    if (existingByUsername) {
      throw new ConflictException('Username already taken');
    }

    const passwordHash = await bcrypt.hash(dto.password, 12);

    const user = await this.usersService.create({
      email: dto.email,
      username: dto.username,
      displayName: dto.displayName,
      password: dto.password,
      passwordHash,
    });

    return this.issueTokens(user);
  }

  async login(dto: LoginDto): Promise<TokenResponse> {
    const user = await this.usersService.findByEmail(dto.email);

    if (!user || !user.passwordHash) {
      throw new UnauthorizedException('Invalid email or password');
    }

    const isPasswordValid = await bcrypt.compare(dto.password, user.passwordHash);

    if (!isPasswordValid) {
      throw new UnauthorizedException('Invalid email or password');
    }

    return this.issueTokens(user);
  }

  async socialLogin(dto: SocialLoginDto): Promise<TokenResponse> {
    // TODO: Validate social token with provider (Apple/Google)
    // For now, we use the idToken as a stub providerUid
    const providerUid = dto.idToken;

    let socialAccount = await this.socialAccountRepository.findOne({
      where: { provider: dto.provider, providerUid },
    });

    if (socialAccount) {
      const user = await this.usersService.findById(socialAccount.userId);
      if (!user) {
        throw new UnauthorizedException('User account not found');
      }
      return this.issueTokens(user);
    }

    // Create new user + social account
    const username = `${dto.provider}_${providerUid.substring(0, 8)}_${Date.now()}`;
    const user = await this.usersService.create({
      email: `${providerUid}@${dto.provider}.social`,
      username,
      password: randomUUID(), // placeholder, not used for social login
      displayName: dto.displayName,
      passwordHash: null,
    });

    socialAccount = this.socialAccountRepository.create({
      userId: user.id,
      provider: dto.provider,
      providerUid,
      email: null,
    });

    await this.socialAccountRepository.save(socialAccount);

    return this.issueTokens(user);
  }

  async refreshToken(refreshToken: string): Promise<TokenResponse> {
    if (!refreshToken) {
      throw new BadRequestException('Refresh token is required');
    }

    const tokenHash = this.hashToken(refreshToken);

    const storedToken = await this.refreshTokenRepository.findOne({
      where: { tokenHash, revokedAt: IsNull() },
    });

    if (!storedToken) {
      throw new UnauthorizedException('Invalid refresh token');
    }

    if (storedToken.expiresAt < new Date()) {
      throw new UnauthorizedException('Refresh token has expired');
    }

    // Revoke old token (rotation)
    storedToken.revokedAt = new Date();
    await this.refreshTokenRepository.save(storedToken);

    const user = await this.usersService.findById(storedToken.userId);
    if (!user) {
      throw new UnauthorizedException('User not found');
    }

    return this.issueTokens(user);
  }

  async logout(refreshToken: string): Promise<void> {
    if (!refreshToken) {
      return;
    }

    const tokenHash = this.hashToken(refreshToken);

    const storedToken = await this.refreshTokenRepository.findOne({
      where: { tokenHash, revokedAt: IsNull() },
    });

    if (storedToken) {
      storedToken.revokedAt = new Date();
      await this.refreshTokenRepository.save(storedToken);
    }
  }

  async deleteAccount(userId: string): Promise<void> {
    // Revoke all refresh tokens for this user
    await this.refreshTokenRepository.update(
      { userId, revokedAt: IsNull() },
      { revokedAt: new Date() },
    );

    // Soft delete the user
    await this.usersService.softDelete(userId);
  }

  private async issueTokens(user: User): Promise<TokenResponse> {
    const jwtConfig = this.configService.get<AppConfig['jwt']>('jwt')!;

    const payload = {
      sub: user.id,
      email: user.email,
      type: 'user' as const,
    };

    const accessToken = this.jwtService.sign(payload, {
      secret: jwtConfig.accessSecret,
      expiresIn: jwtConfig.accessExpiry as StringValue,
    });

    // Generate refresh token as random UUID
    const rawRefreshToken = randomUUID();
    const tokenHash = this.hashToken(rawRefreshToken);

    // Calculate refresh token expiry
    const refreshExpiryMs = this.parseExpiry(jwtConfig.refreshExpiry);
    const expiresAt = new Date(Date.now() + refreshExpiryMs);

    // Store hashed refresh token in DB
    const refreshTokenEntity = this.refreshTokenRepository.create({
      userId: user.id,
      tokenHash,
      expiresAt,
    });

    await this.refreshTokenRepository.save(refreshTokenEntity);

    return {
      accessToken,
      refreshToken: rawRefreshToken,
      expiresIn: 900, // 15 minutes in seconds
      user: {
        id: user.id,
        email: user.email,
        username: user.username,
        displayName: user.displayName,
        bio: user.bio,
        avatarUrl: user.avatarUrl,
        isVerified: user.isVerified,
        isPrivate: user.isPrivate,
        followerCount: user.followerCount,
        followingCount: user.followingCount,
        postCount: user.postCount,
      },
    };
  }

  private hashToken(token: string): string {
    return createHash('sha256').update(token).digest('hex');
  }

  private parseExpiry(expiry: string): number {
    const match = expiry.match(/^(\d+)([smhd])$/);
    if (!match) {
      return 7 * 24 * 60 * 60 * 1000; // default 7 days
    }

    const value = parseInt(match[1], 10);
    const unit = match[2];

    switch (unit) {
      case 's':
        return value * 1000;
      case 'm':
        return value * 60 * 1000;
      case 'h':
        return value * 60 * 60 * 1000;
      case 'd':
        return value * 24 * 60 * 60 * 1000;
      default:
        return 7 * 24 * 60 * 60 * 1000;
    }
  }
}
