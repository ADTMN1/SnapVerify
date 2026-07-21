import { IsString, IsEnum, IsOptional } from 'class-validator';
import { Role } from '@prisma/client';

export class AddStaffDto {
  @IsString()
  fullName: string;

  @IsString()
  phone: string;

  @IsEnum(Role)
  role: Role;

  @IsOptional()
  @IsString()
  password?: string;

  @IsOptional()
  @IsString()
  branchId?: string;
}
