import {
  IsString,
  IsOptional,
  IsEmail,
  Length,
  Matches,
  IsNotEmpty,
  MinLength,
} from 'class-validator';

export class CreateBusinessDto {
  @IsString()
  @IsNotEmpty({ message: 'Business name is required.' })
  name: string;

  @IsString()
  @IsOptional()
  fullName?: string;

  @IsString()
  @IsNotEmpty({ message: 'Phone number is required.' })
  @Matches(/^(\+?251|0)?9\d{8}$/, {
    message:
      'Please enter a valid Ethiopian phone number (e.g., 0912345678, +251912345678)',
  })
  phone: string;

  /**
   * One-time code the owner received via SMS.
   * This proves ownership of the phone number before the business is created.
   */
  @IsString()
  @IsNotEmpty({ message: 'Verification code is required.' })
  @Length(6, 6, { message: 'Verification code must be 6 digits.' })
  otpCode: string;

  @IsString()
  @IsNotEmpty({ message: 'Password is required.' })
  @MinLength(6, { message: 'Password must be at least 6 characters.' })
  password: string;

  @IsEmail()
  @IsOptional()
  email?: string;

  @IsString()
  @IsOptional()
  address?: string;

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
