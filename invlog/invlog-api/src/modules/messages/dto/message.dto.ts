import { IsNotEmpty, IsString, IsUUID, MaxLength } from 'class-validator';

export class StartConversationDto {
  @IsNotEmpty()
  @IsUUID()
  userId: string;
}

export class SendMessageDto {
  @IsNotEmpty()
  @IsString()
  @MaxLength(5000)
  content: string;
}
