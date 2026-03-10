import {
  Controller,
  Post,
  Delete,
  Get,
  Param,
  Query,
  ParseUUIDPipe,
  ParseIntPipe,
  DefaultValuePipe,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { ApiTags, ApiOperation } from '@nestjs/swagger';
import { FollowsService } from './follows.service';
import { CurrentUser, type JwtPayload } from '../../common/decorators/current-user.decorator';

@ApiTags('Follows')
@Controller()
export class FollowsController {
  constructor(private readonly followsService: FollowsService) {}

  @Get('users/:id/followers')
  @ApiOperation({ summary: 'Get followers of a user' })
  async getFollowers(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: JwtPayload,
    @Query('page', new DefaultValuePipe(1), ParseIntPipe) page: number,
    @Query('perPage', new DefaultValuePipe(20), ParseIntPipe) perPage: number,
  ) {
    const result = await this.followsService.getFollowersWithUsers(id, user.sub, page, perPage);
    return result.data;
  }

  @Get('users/:id/following')
  @ApiOperation({ summary: 'Get users followed by a user' })
  async getFollowing(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: JwtPayload,
    @Query('page', new DefaultValuePipe(1), ParseIntPipe) page: number,
    @Query('perPage', new DefaultValuePipe(20), ParseIntPipe) perPage: number,
  ) {
    const result = await this.followsService.getFollowingWithUsers(id, user.sub, page, perPage);
    return result.data;
  }

  @Post('users/:id/follow')
  @ApiOperation({ summary: 'Follow a user' })
  followUser(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: JwtPayload,
  ) {
    return this.followsService.followUser(user.sub, id);
  }

  @Delete('users/:id/follow')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Unfollow a user' })
  unfollowUser(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: JwtPayload,
  ) {
    return this.followsService.unfollowUser(user.sub, id);
  }

  @Post('restaurants/:id/follow')
  @ApiOperation({ summary: 'Follow a restaurant' })
  followRestaurant(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: JwtPayload,
  ) {
    return this.followsService.followRestaurant(user.sub, id);
  }

  @Delete('restaurants/:id/follow')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Unfollow a restaurant' })
  unfollowRestaurant(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: JwtPayload,
  ) {
    return this.followsService.unfollowRestaurant(user.sub, id);
  }
}
