import {
  Controller,
  Get,
  Post,
  Patch,
  Delete,
  Body,
  Param,
  Query,
  ParseUUIDPipe,
} from '@nestjs/common';
import { ApiTags, ApiOperation } from '@nestjs/swagger';
import { CommentsService } from './comments.service';
import { CreateCommentDto, UpdateCommentDto } from './dto/create-comment.dto';
import { CurrentUser, type JwtPayload } from '../../common/decorators/current-user.decorator';
import { PaginationQueryDto } from '../../common/dto/pagination.dto';

@ApiTags('Comments')
@Controller()
export class CommentsController {
  constructor(private readonly commentsService: CommentsService) {}

  @Get('posts/:postId/comments')
  @ApiOperation({ summary: 'List comments for a post (paginated)' })
  findByPost(
    @Param('postId', ParseUUIDPipe) postId: string,
    @Query() query: PaginationQueryDto,
  ) {
    return this.commentsService.findByPostId(postId, query.page, query.perPage);
  }

  @Post('posts/:postId/comments')
  @ApiOperation({ summary: 'Create a comment on a post' })
  create(
    @Param('postId', ParseUUIDPipe) postId: string,
    @CurrentUser() user: JwtPayload,
    @Body() dto: CreateCommentDto,
  ) {
    return this.commentsService.create(postId, user.sub, dto);
  }

  @Patch('comments/:id')
  @ApiOperation({ summary: 'Update a comment (author only)' })
  update(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: JwtPayload,
    @Body() dto: UpdateCommentDto,
  ) {
    return this.commentsService.update(id, user.sub, dto);
  }

  @Delete('comments/:id')
  @ApiOperation({ summary: 'Delete a comment (author only)' })
  remove(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: JwtPayload,
  ) {
    return this.commentsService.remove(id, user.sub);
  }
}
