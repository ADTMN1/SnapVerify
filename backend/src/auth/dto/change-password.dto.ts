import { IsNotEmpty, IsString, MinLength } from 'class-validator';

export class ChangePasswordDto {
  @IsString()
  @IsNotEmpty({ message: 'Current password is required.' })
  currentPassword: string;

  @IsString()
  @IsNotEmpty({ message: 'New password is required.' })
  @MinLength(6, { message: 'New password must be at least 6 characters.' })
  newPassword: string;
}

export class ResetPasswordDto {
  @IsString()
  @IsNotEmpty({ message: 'Phone number is required.' })
  phone: string;

  @IsString()
  @IsNotEmpty({ message: 'Verification code is required.' })
  otpCode: string;

  @IsString()
  @IsNotEmpty({ message: 'New password is required.' })
  @MinLength(6, { message: 'New password must be at least 6 characters.' })
  newPassword: string;
}
