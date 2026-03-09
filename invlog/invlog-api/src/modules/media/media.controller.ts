import { Controller, Post, Get, Param, Body, ParseUUIDPipe } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { MediaService } from './media.service';
import { PresignUploadDto } from './dto/presign-upload.dto';
import { CompleteUploadDto } from './dto/complete-upload.dto';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import type { JwtPayload } from '../../common/decorators/current-user.decorator';

@ApiTags('Media')
@ApiBearerAuth()
@Controller('media')
export class MediaController {
  constructor(private readonly mediaService: MediaService) {}

  @Post('presign')
  @ApiOperation({ summary: 'Get presigned URL for media upload' })
  presign(@CurrentUser() user: JwtPayload, @Body() dto: PresignUploadDto) {
    return this.mediaService.presignUpload(user.sub, dto);
  }

  @Post(':id/complete')
  @ApiOperation({ summary: 'Mark upload complete and trigger processing' })
  complete(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: JwtPayload,
    @Body() dto: CompleteUploadDto,
  ) {
    return this.mediaService.completeUpload(id, user.sub, dto);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get media status' })
  findOne(@Param('id', ParseUUIDPipe) id: string) {
    return this.mediaService.findById(id);
  }
}
