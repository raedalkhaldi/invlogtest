import { Controller, Post, Delete, Param } from '@nestjs/common';
import { BlocksService } from './blocks.service';
import { CurrentUser, type JwtPayload } from '../../common/decorators/current-user.decorator';

@Controller('users')
export class BlocksController {
  constructor(private readonly blocksService: BlocksService) {}

  @Post(':id/block')
  async blockUser(
    @Param('id') targetId: string,
    @CurrentUser() user: JwtPayload,
  ) {
    return this.blocksService.blockUser(user.sub, targetId);
  }

  @Delete(':id/block')
  async unblockUser(
    @Param('id') targetId: string,
    @CurrentUser() user: JwtPayload,
  ) {
    await this.blocksService.unblockUser(user.sub, targetId);
    return { success: true };
  }
}
