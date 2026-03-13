import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Block } from './entities/block.entity';
import { User } from '../users/entities/user.entity';
import { Follow } from '../follows/entities/follow.entity';
import { BlocksService } from './blocks.service';
import { BlocksController } from './blocks.controller';

@Module({
  imports: [TypeOrmModule.forFeature([Block, User, Follow])],
  controllers: [BlocksController],
  providers: [BlocksService],
  exports: [BlocksService],
})
export class BlocksModule {}
