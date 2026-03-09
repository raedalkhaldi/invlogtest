import { IsEnum, IsString, IsOptional } from 'class-validator';

export enum SocialProvider {
  APPLE = 'apple',
  GOOGLE = 'google',
}

export class SocialLoginDto {
  @IsEnum(SocialProvider)
  provider!: SocialProvider;

  @IsString()
  idToken!: string;

  @IsOptional()
  @IsString()
  displayName?: string;
}
