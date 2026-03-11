import {
  IsString,
  IsOptional,
  IsUUID,
  IsInt,
  IsNumber,
  IsIn,
  Min,
  MaxLength,
} from 'class-validator';

export class UpdateStopDto {
  @IsOptional()
  @IsString()
  @MaxLength(255)
  name?: string;

  @IsOptional()
  @IsUUID()
  restaurantId?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  address?: string;

  @IsOptional()
  @IsNumber()
  latitude?: number;

  @IsOptional()
  @IsNumber()
  longitude?: number;

  @IsOptional()
  @IsInt()
  @Min(1)
  dayNumber?: number;

  @IsOptional()
  @IsInt()
  @Min(0)
  sortOrder?: number;

  @IsOptional()
  @IsString()
  @MaxLength(5)
  startTime?: string;

  @IsOptional()
  @IsString()
  @MaxLength(5)
  endTime?: string;

  @IsOptional()
  @IsString()
  @MaxLength(5000)
  notes?: string;

  @IsOptional()
  @IsIn(['restaurant', 'cafe', 'attraction', 'hotel', 'other'])
  category?: 'restaurant' | 'cafe' | 'attraction' | 'hotel' | 'other';

  @IsOptional()
  @IsInt()
  @Min(1)
  estimatedDuration?: number;
}
