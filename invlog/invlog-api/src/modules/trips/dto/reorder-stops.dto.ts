import { IsArray, IsUUID } from 'class-validator';

export class ReorderStopsDto {
  @IsArray()
  @IsUUID('4', { each: true })
  stopIds: string[];
}
