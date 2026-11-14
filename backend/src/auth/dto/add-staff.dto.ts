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

  @IsString()
  @IsNotEmpty({ message: 'Phone number is required.' })
  @Matches(/^(\+?251|0)?9\d{8}$/, {
    message: 'Please enter a valid Ethiopian phone number.',
  })
  phone: string;

  @IsEnum(Role, { message: 'Please select a valid role.' })
  role: Role;

  @IsOptional()
  @IsString()
  password?: string;

  @IsOptional()
  @IsString()
  branchId?: string;
}
