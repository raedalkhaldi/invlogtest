import {
  IsString,
  IsOptional,
  IsIn,
  IsNumber,
  MinLength,
  MaxLength,
  Max,
} from 'class-validator';
import { Type } from 'class-transformer';

export class SearchQueryDto {
  @IsOptional()
  @IsString()
  @MaxLength(100)
  q?: string;

  @IsOptional()
  @IsIn(['restaurants', 'people', 'posts'])
  type?: string;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  lat?: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  lng?: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Max(50)
  limit?: number;
}
