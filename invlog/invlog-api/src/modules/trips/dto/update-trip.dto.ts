import {
  IsString,
  IsOptional,
  IsIn,
  IsDateString,
  MaxLength,
} from 'class-validator';

export class UpdateTripDto {
  @IsOptional()
  @IsString()
  @MaxLength(255)
  title?: string;

  @IsOptional()
  @IsString()
  @MaxLength(5000)
  description?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  coverImageUrl?: string;

  @IsOptional()
  @IsDateString()
  startDate?: string;

  @IsOptional()
  @IsDateString()
  endDate?: string;

  @IsOptional()
  @IsIn(['public', 'private'])
  visibility?: 'public' | 'private';

  @IsOptional()
  @IsIn(['planning', 'active', 'completed'])
  status?: 'planning' | 'active' | 'completed';
}
