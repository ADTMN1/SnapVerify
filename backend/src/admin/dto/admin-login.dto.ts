import { IsEmail, IsOptional, IsString, MinLength } from 'class-validator';

export class AdminLoginDto {
  @IsEmail()
  email: string;

  @IsString()
  @MinLength(6)
  password: string;
}

export class AdminChangePasswordDto {
  @IsString()
  @MinLength(6)
  currentPassword: string;

  @IsString()
  @MinLength(6)
  newPassword: string;
}

export class AdminUpdateProfileDto {
  @IsString()
  @MinLength(6)
  currentPassword: string;

  @IsOptional()
  @IsEmail()
  newEmail?: string;
}

export class AdminRefreshTokenDto {
  @IsString()
  refreshToken: string;
}

export class AdminLogoutDto {
  @IsString()
  refreshToken: string;
}

export class AdminForgotPasswordDto {
  @IsEmail()
  email: string;
}

export class AdminResetPasswordDto {
  @IsEmail()
  email: string;

  @IsString()
  @MinLength(6)
  otpCode: string;

  @IsString()
  @MinLength(8)
  newPassword: string;
}
