import {
  IsBoolean,
  IsIn,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';

export class UpdatePlatformOrganizationDto {
  @IsOptional()
  @IsIn(['active', 'suspended', 'inactive'])
  status?: string;

  @IsOptional()
  @IsString()
  @MaxLength(100)
  subscriptionPlan?: string;
}

export class UpdatePlatformUserDto {
  @IsOptional()
  @IsIn(['active', 'inactive', 'suspended'])
  status?: string;

  @IsOptional()
  @IsBoolean()
  isPlatformAdmin?: boolean;
}
