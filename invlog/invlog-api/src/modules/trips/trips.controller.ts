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
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { ApiTags, ApiOperation } from '@nestjs/swagger';
import { TripsService } from './trips.service';
import { CreateTripDto } from './dto/create-trip.dto';
import { UpdateTripDto } from './dto/update-trip.dto';
import { AddStopDto } from './dto/add-stop.dto';
import { UpdateStopDto } from './dto/update-stop.dto';
import { InviteCollaboratorDto } from './dto/invite-collaborator.dto';
import { ReorderStopsDto } from './dto/reorder-stops.dto';
import {
  CurrentUser,
  type JwtPayload,
} from '../../common/decorators/current-user.decorator';
import { CursorQueryDto } from '../../common/dto/pagination.dto';

@ApiTags('Trips')
@Controller()
export class TripsController {
  constructor(private readonly tripsService: TripsService) {}

  @Post('trips')
  @ApiOperation({ summary: 'Create a new trip' })
  create(
    @CurrentUser() user: JwtPayload,
    @Body() dto: CreateTripDto,
  ) {
    return this.tripsService.create(user.sub, dto);
  }

  @Get('trips/mine')
  @ApiOperation({ summary: 'List my trips (owned + collaborating)' })
  findAll(
    @CurrentUser() user: JwtPayload,
    @Query() query: CursorQueryDto,
  ) {
    return this.tripsService.findAll(user.sub, query.cursor, query.limit);
  }

  @Get('trips/explore')
  @ApiOperation({ summary: 'Browse public trips' })
  findPublic(@Query() query: CursorQueryDto) {
    return this.tripsService.findPublic(query.cursor, query.limit);
  }

  @Get('trips/:id')
  @ApiOperation({ summary: 'Get a trip by ID' })
  findOne(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: JwtPayload,
  ) {
    return this.tripsService.findOne(id, user.sub);
  }

  @Patch('trips/:id')
  @ApiOperation({ summary: 'Update a trip (owner or editor)' })
  update(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: JwtPayload,
    @Body() dto: UpdateTripDto,
  ) {
    return this.tripsService.update(id, user.sub, dto);
  }

  @Delete('trips/:id')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Delete a trip (owner only)' })
  delete(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: JwtPayload,
  ) {
    return this.tripsService.delete(id, user.sub);
  }

  @Post('trips/:id/stops')
  @ApiOperation({ summary: 'Add a stop to a trip' })
  addStop(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: JwtPayload,
    @Body() dto: AddStopDto,
  ) {
    return this.tripsService.addStop(id, user.sub, dto);
  }

  @Patch('trips/stops/:stopId')
  @ApiOperation({ summary: 'Update a stop' })
  updateStop(
    @Param('stopId', ParseUUIDPipe) stopId: string,
    @CurrentUser() user: JwtPayload,
    @Body() dto: UpdateStopDto,
  ) {
    return this.tripsService.updateStop(stopId, user.sub, dto);
  }

  @Delete('trips/stops/:stopId')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Remove a stop' })
  removeStop(
    @Param('stopId', ParseUUIDPipe) stopId: string,
    @CurrentUser() user: JwtPayload,
  ) {
    return this.tripsService.removeStop(stopId, user.sub);
  }

  @Patch('trips/:id/stops/reorder')
  @ApiOperation({ summary: 'Reorder stops in a trip' })
  reorderStops(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: JwtPayload,
    @Body() dto: ReorderStopsDto,
  ) {
    return this.tripsService.reorderStops(id, user.sub, dto.stopIds);
  }

  @Post('trips/:id/collaborators')
  @ApiOperation({ summary: 'Invite a collaborator (owner only)' })
  inviteCollaborator(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: JwtPayload,
    @Body() dto: InviteCollaboratorDto,
  ) {
    return this.tripsService.inviteCollaborator(id, user.sub, dto);
  }

  @Delete('trips/:id/collaborators/:userId')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Remove a collaborator (owner only)' })
  removeCollaborator(
    @Param('id', ParseUUIDPipe) id: string,
    @Param('userId', ParseUUIDPipe) collaboratorUserId: string,
    @CurrentUser() user: JwtPayload,
  ) {
    return this.tripsService.removeCollaborator(id, user.sub, collaboratorUserId);
  }

  @Post('trips/:id/clone')
  @ApiOperation({ summary: 'Clone a public trip to your own trips' })
  cloneTrip(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: JwtPayload,
  ) {
    return this.tripsService.cloneTrip(id, user.sub);
  }

  @Get('users/:username/trips')
  @ApiOperation({ summary: "Get a user's public trips" })
  findByUser(
    @Param('username') username: string,
    @Query() query: CursorQueryDto,
  ) {
    return this.tripsService.findByUser(username, query.cursor, query.limit);
  }
}
