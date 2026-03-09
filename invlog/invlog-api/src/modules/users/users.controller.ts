import {
  Controller,
  Get,
  Patch,
  Param,
  Body,
  Query,
  NotFoundException,
  ParseUUIDPipe,
} from '@nestjs/common';
import { ApiTags, ApiBearerAuth } from '@nestjs/swagger';
import { UsersService } from './users.service.js';
import { FollowsService } from '../follows/follows.service';
import { PostsService } from '../posts/posts.service';
import { UpdateUserDto } from './dto/update-user.dto.js';
import { CurrentUser, type JwtPayload } from '../../common/decorators/current-user.decorator.js';
import { CursorQueryDto } from '../../common/dto/pagination.dto';

@ApiTags('users')
@ApiBearerAuth()
@Controller('users')
export class UsersController {
  constructor(
    private readonly usersService: UsersService,
    private readonly followsService: FollowsService,
    private readonly postsService: PostsService,
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

  @Get(':username/posts')
  async getUserPosts(
    @Param('username') username: string,
    @Query() query: CursorQueryDto,
  ) {
    // username param can be a UUID (userId) or a username
    let userId = username;

    // If it looks like a UUID, use directly; otherwise look up by username
    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    if (!uuidRegex.test(username)) {
      const user = await this.usersService.findByUsername(username);
      if (!user) throw new NotFoundException('User not found');
      userId = user.id;
    }

    return this.postsService.findByAuthor(userId, query.cursor, query.limit);
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
