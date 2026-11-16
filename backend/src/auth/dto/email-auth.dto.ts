import {
  IsString,
  IsEmail,
  IsNotEmpty,
  MinLength,
  IsOptional,
  Matches,
} from 'class-validator';

export class RegisterDto {
  @IsString()
  @IsNotEmpty({ message: 'Business name is required.' })
  name: string;

  @IsString()
  @IsNotEmpty({ message: 'Full name is required.' })
  fullName: string;

  @IsEmail({}, { message: 'Please enter a valid email address.' })
  @IsNotEmpty({ message: 'Email is required.' })
  email: string;

  @IsString()
  @IsNotEmpty({ message: 'Password is required.' })
  @MinLength(8, { message: 'Password must be at least 8 characters.' })
  password: string;

  @IsString()
  @IsNotEmpty({ message: 'Please confirm your password.' })
  confirmPassword: string;

  @IsString()
  @IsOptional()
  type?: string;

  @IsString()
  @IsOptional()
  city?: string;

  @IsString()
  @IsOptional()
  country?: string;
}

export class VerifyEmailDto {
  @IsEmail({}, { message: 'Please enter a valid email address.' })
  email: string;

  @IsString()
  @IsNotEmpty({ message: 'Verification code is required.' })
  @Matches(/^\d{6}$/, { message: 'Verification code must be 6 digits.' })
  otpCode: string;
}

export class ResendVerificationDto {
  @IsEmail({}, { message: 'Please enter a valid email address.' })
  email: string;
}

export class ForgotPasswordDto {
  @IsEmail({}, { message: 'Please enter a valid email address.' })
  email: string;
}

export class ResetPasswordDto {
  @IsEmail({}, { message: 'Please enter a valid email address.' })
  email: string;

  @IsString()
  @IsNotEmpty({ message: 'Verification code is required.' })
  @Matches(/^\d{6}$/, { message: 'Verification code must be 6 digits.' })
  otpCode: string;

  @IsString()
  @IsNotEmpty({ message: 'New password is required.' })
  @MinLength(8, { message: 'New password must be at least 8 characters.' })
  newPassword: string;
}

export class StaffActivationOtpDto {
  @IsEmail({}, { message: 'Please enter a valid email address.' })
  email: string;

  @IsOptional()
  @IsString()
  token?: string;
}

export class ActivateInvitationDto {
  @IsOptional()
  @IsString()
  token?: string;

  @IsEmail({}, { message: 'Please enter a valid email address.' })
  email: string;

  @IsString()
  @IsNotEmpty({ message: 'Verification code is required.' })
  @Matches(/^\d{6}$/, { message: 'Verification code must be 6 digits.' })
  otpCode: string;

  @IsString()
  @IsNotEmpty({ message: 'Full name is required.' })
  fullName: string;

  @IsString()
  @IsNotEmpty({ message: 'Password is required.' })
  @MinLength(8, { message: 'Password must be at least 8 characters.' })
  password: string;
}
