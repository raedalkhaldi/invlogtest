import {
  Controller,
  Post,
  Delete,
  Param,
  ParseUUIDPipe,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { ApiTags, ApiOperation } from '@nestjs/swagger';
import { LikesService } from './likes.service';
import { CurrentUser, type JwtPayload } from '../../common/decorators/current-user.decorator';

@ApiTags('Likes')
@Controller()
export class LikesController {
  constructor(private readonly likesService: LikesService) {}

  @Post('posts/:id/like')
  @ApiOperation({ summary: 'Like a post' })
  likePost(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: JwtPayload,
  ) {
    return this.likesService.likePost(user.sub, id);
  }

  @Delete('posts/:id/like')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Unlike a post' })
  unlikePost(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: JwtPayload,
  ) {
    return this.likesService.unlikePost(user.sub, id);
  }

  @Post('comments/:id/like')
  @ApiOperation({ summary: 'Like a comment' })
  likeComment(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: JwtPayload,
  ) {
    return this.likesService.likeComment(user.sub, id);
  }

  @Delete('comments/:id/like')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Unlike a comment' })
  unlikeComment(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: JwtPayload,
  ) {
    return this.likesService.unlikeComment(user.sub, id);
  }
}
