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
import { RestaurantsService } from './restaurants.service';
import {
  CreateRestaurantDto,
  UpdateRestaurantDto,
  CreateMenuItemDto,
  NearbyQueryDto,
} from './dto/create-restaurant.dto';
import { CurrentUser, type JwtPayload } from '../../common/decorators/current-user.decorator';
import { PaginationQueryDto } from '../../common/dto/pagination.dto';

@ApiTags('Restaurants')
@Controller('restaurants')
export class RestaurantsController {
  constructor(private readonly restaurantsService: RestaurantsService) {}

  @Post()
  @ApiOperation({ summary: 'Create a restaurant' })
  create(
    @CurrentUser() user: JwtPayload,
    @Body() dto: CreateRestaurantDto,
  ) {
    return this.restaurantsService.create(user.sub, dto);
  }

  @Get('nearby')
  @ApiOperation({ summary: 'Find nearby restaurants' })
  findNearby(@Query() query: NearbyQueryDto) {
    return this.restaurantsService.findNearby(query);
  }

  @Get(':slug')
  @ApiOperation({ summary: 'Get a restaurant by slug' })
  findBySlug(@Param('slug') slug: string) {
    return this.restaurantsService.findBySlug(slug);
  }

  @Patch(':id')
  @ApiOperation({ summary: 'Update a restaurant (owner only)' })
  update(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: JwtPayload,
    @Body() dto: UpdateRestaurantDto,
  ) {
    return this.restaurantsService.update(id, user.sub, dto);
  }

  @Get(':id/checkins')
  @ApiOperation({ summary: 'Get check-ins for a restaurant' })
  async getCheckins(
    @Param('id', ParseUUIDPipe) id: string,
    @Query() query: PaginationQueryDto,
  ) {
    const result = await this.restaurantsService.getCheckins(id, query.page, query.perPage);
    return result.data;
  }

  @Get(':id/operating-hours')
  @ApiOperation({ summary: 'Get operating hours for a restaurant' })
  getOperatingHours(@Param('id', ParseUUIDPipe) id: string) {
    return this.restaurantsService.getOperatingHours(id);
  }

  @Get(':id/menu')
  @ApiOperation({ summary: 'Get menu items for a restaurant' })
  getMenu(@Param('id', ParseUUIDPipe) id: string) {
    return this.restaurantsService.getMenuItems(id);
  }

  @Post(':id/menu')
  @ApiOperation({ summary: 'Add a menu item (owner only)' })
  createMenuItem(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: JwtPayload,
    @Body() dto: CreateMenuItemDto,
  ) {
    return this.restaurantsService.createMenuItem(id, user.sub, dto);
  }

  @Patch(':id/menu/:itemId')
  @ApiOperation({ summary: 'Update a menu item (owner only)' })
  updateMenuItem(
    @Param('id', ParseUUIDPipe) id: string,
    @Param('itemId', ParseUUIDPipe) itemId: string,
    @CurrentUser() user: JwtPayload,
    @Body() dto: CreateMenuItemDto,
  ) {
    return this.restaurantsService.updateMenuItem(id, itemId, user.sub, dto);
  }

  @Delete(':id/menu/:itemId')
  @ApiOperation({ summary: 'Delete a menu item (owner only)' })
  deleteMenuItem(
    @Param('id', ParseUUIDPipe) id: string,
    @Param('itemId', ParseUUIDPipe) itemId: string,
    @CurrentUser() user: JwtPayload,
  ) {
    return this.restaurantsService.deleteMenuItem(id, itemId, user.sub);
  }
}
