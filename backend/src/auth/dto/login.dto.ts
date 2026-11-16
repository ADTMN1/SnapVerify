import {
  IsString,
  IsNotEmpty,
  MinLength,
  IsOptional,
} from 'class-validator';

export class LoginDto {
  // Email for new users; legacy phone login is still accepted for existing
  // users that predate the email-auth migration.
  @IsString()
  @IsNotEmpty({ message: 'Email is required.' })
  identifier: string;

  @IsString()
  @IsNotEmpty({ message: 'Password is required.' })
  password: string;

  @IsString()
  @IsOptional()
  organizationId?: string;
}
