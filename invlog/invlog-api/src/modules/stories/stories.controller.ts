import {
  Controller,
  Post,
  Get,
  Delete,
  Param,
  Body,
  ParseUUIDPipe,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { ApiTags, ApiOperation } from '@nestjs/swagger';
import { StoriesService } from './stories.service';
import { CreateStoryDto } from './dto/create-story.dto';
import {
  CurrentUser,
  type JwtPayload,
} from '../../common/decorators/current-user.decorator';

@ApiTags('Stories')
@Controller('stories')
export class StoriesController {
  constructor(private readonly storiesService: StoriesService) {}

  @Post()
  @ApiOperation({ summary: 'Create a story' })
  create(
    @CurrentUser() user: JwtPayload,
    @Body() dto: CreateStoryDto,
  ) {
    return this.storiesService.create(user.sub, dto.mediaId);
  }

  @Get('feed')
  @ApiOperation({ summary: 'Get story feed' })
  getFeed(@CurrentUser() user: JwtPayload) {
    return this.storiesService.getFeed(user.sub);
  }

  @Post(':id/view')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Mark story as viewed' })
  markViewed(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: JwtPayload,
  ) {
    return this.storiesService.markViewed(user.sub, id);
  }

  @Get(':id/viewers')
  @ApiOperation({ summary: 'Get story viewers (author only)' })
  getViewers(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: JwtPayload,
  ) {
    return this.storiesService.getViewers(user.sub, id);
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Delete a story' })
  deleteStory(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: JwtPayload,
  ) {
    return this.storiesService.deleteStory(user.sub, id);
  }
}
