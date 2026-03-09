import {
  Controller,
  Get,
  Patch,
  Param,
  Body,
  NotFoundException,
} from '@nestjs/common';
import { ApiTags, ApiBearerAuth } from '@nestjs/swagger';
import { UsersService } from './users.service.js';
import { FollowsService } from '../follows/follows.service';
import { UpdateUserDto } from './dto/update-user.dto.js';
import { CurrentUser, type JwtPayload } from '../../common/decorators/current-user.decorator.js';

@ApiTags('users')
@ApiBearerAuth()
@Controller('users')
export class UsersController {
  constructor(
    private readonly usersService: UsersService,
    private readonly followsService: FollowsService,
  ) {}

  @Get('me')
  async getProfile(@CurrentUser() user: JwtPayload) {
    const found = await this.usersService.findById(user.sub);

    if (!found) {
      throw new NotFoundException('User not found');
    }

    const { passwordHash, ...profile } = found;
    return profile;
  }

  @Patch('me')
  async updateProfile(
    @CurrentUser() user: JwtPayload,
    @Body() dto: UpdateUserDto,
  ) {
    const updated = await this.usersService.updateProfile(user.sub, dto);
    const { passwordHash, ...profile } = updated;
    return profile;
  }

  @Get(':username')
  async getPublicProfile(
    @Param('username') username: string,
    @CurrentUser() user: JwtPayload,
  ) {
    const found = await this.usersService.findByUsername(username);

    if (!found) {
      throw new NotFoundException('User not found');
    }

    const isFollowedByMe = await this.followsService.isFollowing(
      user.sub,
      'user',
      found.id,
    );

    const { passwordHash, deletedAt, ...publicProfile } = found;
    return { ...publicProfile, isFollowedByMe };
  }
}
