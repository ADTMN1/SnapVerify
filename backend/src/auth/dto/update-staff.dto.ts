import { IsString, IsEnum, IsOptional, IsNotEmpty } from 'class-validator';
import { Role } from '@prisma/client';

export class UpdateStaffDto {
  @IsString()
  @IsNotEmpty({ message: 'Full name is required.' })
  fullName: string;

  @IsEnum(Role, { message: 'Please select a valid role.' })
  role: Role;

  @IsOptional()
  @IsString()
  branchId?: string;
}
