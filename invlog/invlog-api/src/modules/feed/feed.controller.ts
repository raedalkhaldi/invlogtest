import { Controller, DefaultValuePipe, Get, ParseIntPipe, Query } from '@nestjs/common';
import { ApiTags, ApiOperation } from '@nestjs/swagger';
import { FeedService } from './feed.service';
import { CurrentUser, type JwtPayload } from '../../common/decorators/current-user.decorator';
import { CursorQueryDto } from '../../common/dto/pagination.dto';

@ApiTags('Feed')
@Controller('feed')
export class FeedController {
  constructor(private readonly feedService: FeedService) {}

  @Get()
  @ApiOperation({ summary: 'Get personalized feed (cursor paginated)' })
  getFeed(
    @CurrentUser() user: JwtPayload,
    @Query() query: CursorQueryDto,
  ) {
    return this.feedService.getFeed(user.sub, query.cursor, query.limit);
  }

  @Get('explore')
  @ApiOperation({ summary: 'Get explore feed of public posts (cursor paginated)' })
  async getExploreFeed(
    @CurrentUser() user: JwtPayload,
    @Query('cursor') cursor?: string,
    @Query('limit', new DefaultValuePipe(20), ParseIntPipe) limit?: number,
  ) {
    return this.feedService.getExploreFeed(user.sub, cursor, limit);
  }
}
