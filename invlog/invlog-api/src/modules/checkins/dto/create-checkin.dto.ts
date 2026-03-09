import { IsUUID, IsOptional, IsNumber } from 'class-validator';

export class CreateCheckInDto {
  @IsUUID()
  restaurantId: string;

  @IsOptional()
  @IsUUID()
  postId?: string;

  @IsOptional()
  @IsNumber()
  latitude?: number;

  @IsOptional()
  @IsNumber()
  longitude?: number;
}
