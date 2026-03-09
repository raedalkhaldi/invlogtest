import { IsString, MaxLength, IsIn } from 'class-validator';

export class RegisterDeviceTokenDto {
  @IsString()
  @MaxLength(500)
  token: string;

  @IsString()
  @IsIn(['ios', 'android', 'web'])
  platform: string;
}
