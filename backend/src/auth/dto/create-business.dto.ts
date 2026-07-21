import {
  IsString,
  IsOptional,
  IsEmail,
  Length,
  Matches,
} from 'class-validator';

export class CreateBusinessDto {
  @IsString()
  name: string;

  @IsString()
  @IsOptional()
  fullName?: string;

  @IsString()
  @Matches(/^(\+?251|0)?9\d{8}$/, {
    message:
      'phone must be a valid Ethiopian phone number (e.g., 0912345678, +251912345678)',
  })
  phone: string;

  /**
   * One-time code the owner received via SMS.
   * This proves ownership of the phone number before the business is created.
   */
  @IsString()
  @Length(6, 6)
  otpCode: string;

  @IsString()
  @Length(6, 100)
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
