import { IsString, IsIn, IsInt, Min, Max } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class PresignUploadDto {
  @ApiProperty({ example: 'photo_1.jpg' })
  @IsString()
  fileName: string;

  @ApiProperty({ example: 'image/jpeg' })
  @IsString()
  @IsIn([
    'image/jpeg',
    'image/png',
    'image/heic',
    'image/heif',
    'image/webp',
    'video/mp4',
    'video/quicktime',
    'video/mov',
  ])
  contentType: string;

  @ApiProperty({ example: 2048000 })
  @IsInt()
  @Min(1)
  @Max(50 * 1024 * 1024) // 50MB (videos can be larger)
  fileSize: number;
}
