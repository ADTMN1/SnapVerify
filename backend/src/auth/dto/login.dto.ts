import {
  IsString,
  IsOptional,
  Matches,
  Length,
  IsNotEmpty,
} from 'class-validator';

export class LoginDto {
  @IsString()
  @Matches(/^(\+?251|0)?9\d{8}$/, {
    message:
      'Please enter a valid Ethiopian phone number (e.g., 0912345678, +251912345678)',
  })
  phone: string;

  @IsString()
  @IsNotEmpty()
  password: string;

  @IsString()
  @IsOptional()
  organizationId?: string;
}
