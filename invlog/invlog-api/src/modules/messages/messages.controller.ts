import {
  Controller,
  Post,
  Get,
  Patch,
  Param,
  Body,
  Query,
  ParseUUIDPipe,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { ApiTags, ApiOperation } from '@nestjs/swagger';
import { MessagesService } from './messages.service';
import { StartConversationDto, SendMessageDto } from './dto/message.dto';
import {
  CurrentUser,
  type JwtPayload,
} from '../../common/decorators/current-user.decorator';
import { CursorQueryDto } from '../../common/dto/pagination.dto';

@ApiTags('Messages')
@Controller('conversations')
export class MessagesController {
  constructor(private readonly messagesService: MessagesService) {}

  @Get()
  @ApiOperation({ summary: 'List conversations' })
  listConversations(
    @CurrentUser() user: JwtPayload,
    @Query() query: CursorQueryDto,
  ) {
    return this.messagesService.getConversations(
      user.sub,
      query.cursor,
      query.limit,
    );
  }

  @Post()
  @ApiOperation({ summary: 'Start or get a conversation' })
  startConversation(
    @CurrentUser() user: JwtPayload,
    @Body() dto: StartConversationDto,
  ) {
    return this.messagesService.startConversation(user.sub, dto.userId);
  }

  @Get(':id/messages')
  @ApiOperation({ summary: 'Get messages in conversation' })
  getMessages(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: JwtPayload,
    @Query() query: CursorQueryDto,
  ) {
    return this.messagesService.getMessages(
      user.sub,
      id,
      query.cursor,
      query.limit,
    );
  }

  @Post(':id/messages')
  @ApiOperation({ summary: 'Send a message' })
  sendMessage(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: JwtPayload,
    @Body() dto: SendMessageDto,
  ) {
    return this.messagesService.sendMessage(user.sub, id, dto.content);
  }

  @Patch(':id/read')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Mark all messages as read' })
  markAsRead(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: JwtPayload,
  ) {
    return this.messagesService.markAsRead(user.sub, id);
  }
}
