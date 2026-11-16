import {
  IsString,
  IsEnum,
  IsOptional,
  IsNotEmpty,
  IsEmail,
  Matches,
} from 'class-validator';
import { Role } from '@prisma/client';

export class AddStaffDto {
  @IsString()
  @IsNotEmpty({ message: 'Full name is required.' })
  fullName: string;

  @IsOptional()
  @IsEmail({}, { message: 'Please enter a valid email address.' })
  email?: string;

  @IsOptional()
  @IsString()
  @Matches(/^(\+?251|0)?9\d{8}$/, {
    message: 'Please enter a valid Ethiopian phone number.',
  })
  phone?: string;

  @IsEnum(Role, { message: 'Please select a valid role.' })
  role: Role;

  @IsOptional()
  @IsString()
  branchId?: string;
}
