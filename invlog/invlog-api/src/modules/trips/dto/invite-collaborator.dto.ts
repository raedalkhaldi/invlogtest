import {
  IsUUID,
  IsOptional,
  IsIn,
  IsNotEmpty,
} from 'class-validator';

export class InviteCollaboratorDto {
  @IsNotEmpty()
  @IsUUID()
  userId: string;

  @IsOptional()
  @IsIn(['editor', 'viewer'])
  role?: 'editor' | 'viewer';
}
