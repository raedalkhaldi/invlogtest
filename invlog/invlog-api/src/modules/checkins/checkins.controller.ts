import {
  Controller,
  Get,
  Post,
  Body,
  Param,
  Query,
  ParseUUIDPipe,
} from '@nestjs/common';
import { ApiTags, ApiOperation } from '@nestjs/swagger';
import { CheckInsService } from './checkins.service';
import { CreateCheckInDto } from './dto/create-checkin.dto';
import { CurrentUser, type JwtPayload } from '../../common/decorators/current-user.decorator';
import { PaginationQueryDto } from '../../common/dto/pagination.dto';

@ApiTags('Check-ins')
@Controller('checkins')
export class CheckInsController {
  constructor(private readonly checkinsService: CheckInsService) {}

  @Post()
  @ApiOperation({ summary: 'Create a check-in' })
  create(
    @CurrentUser() user: JwtPayload,
    @Body() dto: CreateCheckInDto,
  ) {
    return this.checkinsService.create(user.sub, dto);
  }

  @Get('recent')
  @ApiOperation({ summary: 'Get recent check-ins' })
  async findRecent(@Query() query: PaginationQueryDto) {
    const result = await this.checkinsService.findRecent(query.page, query.perPage);
    return result.data;
  }

  @Get('user/:userId')
  @ApiOperation({ summary: 'Get check-ins by a specific user' })
  async findByUser(
    @Param('userId', ParseUUIDPipe) userId: string,
    @Query() query: PaginationQueryDto,
  ) {
    const result = await this.checkinsService.findByUserId(userId, query.page, query.perPage);
    return result.data;
  }
}
