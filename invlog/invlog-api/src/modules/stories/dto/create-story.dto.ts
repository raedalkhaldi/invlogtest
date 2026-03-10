import { IsNotEmpty, IsUUID } from 'class-validator';

export class CreateStoryDto {
  @IsNotEmpty()
  @IsUUID()
  mediaId: string;
}
