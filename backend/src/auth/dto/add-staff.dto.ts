import {
  IsString,
  IsEnum,
  IsOptional,
  IsNotEmpty,
  Matches,
} from 'class-validator';
import { Role } from '@prisma/client';

export class AddStaffDto {
  @IsString()
  @IsNotEmpty({ message: 'Full name is required.' })
  fullName: string;

  // Staff log in with username + password after QR activation.
  @IsString()
  @IsNotEmpty({ message: 'Username is required.' })
  @Matches(/^[a-zA-Z0-9._-]{3,30}$/, {
    message:
      'Username must be 3-30 characters: letters, numbers, dots, dashes or underscores.',
  })
  username: string;

  @IsEnum(Role, { message: 'Please select a valid role.' })
  role: Role;

  @IsOptional()
  @IsString()
  branchId?: string;
}
