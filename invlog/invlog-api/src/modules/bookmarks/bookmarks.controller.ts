import {
  Controller,
  Post,
  Delete,
  Get,
  Param,
  Query,
  ParseUUIDPipe,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { ApiTags, ApiOperation } from '@nestjs/swagger';
import { BookmarksService } from './bookmarks.service';
import { PostsService } from '../posts/posts.service';
import {
  CurrentUser,
  type JwtPayload,
} from '../../common/decorators/current-user.decorator';
import { CursorQueryDto } from '../../common/dto/pagination.dto';

@ApiTags('Bookmarks')
@Controller()
export class BookmarksController {
  constructor(
    private readonly bookmarksService: BookmarksService,
    private readonly postsService: PostsService,
  ) {}

  @Post('posts/:id/bookmark')
  @ApiOperation({ summary: 'Bookmark a post' })
  bookmarkPost(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: JwtPayload,
  ) {
    return this.bookmarksService.bookmark(user.sub, id);
  }

  @Delete('posts/:id/bookmark')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Remove bookmark' })
  removeBookmark(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: JwtPayload,
  ) {
    return this.bookmarksService.removeBookmark(user.sub, id);
  }

  @Get('bookmarks')
  @ApiOperation({ summary: 'List saved posts' })
  async listBookmarks(
    @CurrentUser() user: JwtPayload,
    @Query() query: CursorQueryDto,
  ) {
    const { data: bookmarks, nextCursor } =
      await this.bookmarksService.getBookmarkedPostIds(
        user.sub,
        query.cursor,
        query.limit,
      );

    if (!bookmarks.length) {
      return { data: [], nextCursor: null };
    }

    const postIds = bookmarks.map((b) => b.postId);
    const posts = await this.postsService.findByIds(postIds);

    // Preserve bookmark order
    const postMap = new Map(posts.map((p) => [p.id, p]));
    const orderedPosts = postIds
      .map((id) => postMap.get(id))
      .filter(Boolean);

    return { data: orderedPosts, nextCursor };
  }
}
