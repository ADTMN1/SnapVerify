import {
  IsBoolean,
  IsInt,
  IsOptional,
  IsString,
  MaxLength,
  Min,
} from 'class-validator';

export class CreateSubscriptionPlanDto {
  @IsOptional()
  @IsString()
  @MaxLength(60)
  id?: string;

  @IsString()
  @MaxLength(60)
  name!: string;

  @IsInt()
  @Min(0)
  price!: number;

  @IsOptional()
  @IsString()
  @MaxLength(10)
  currency?: string;

  @IsOptional()
  @IsInt()
  @Min(1)
  durationDays?: number | null;

  @IsOptional()
  @IsInt()
  @Min(1)
  durationMonths?: number | null;

  @IsOptional()
  @IsBoolean()
  isLifetime?: boolean;

  @IsOptional()
  @IsInt()
  @Min(0)
  verificationLimit?: number | null;

  @IsOptional()
  @IsInt()
  @Min(0)
  maxUsers?: number | null;

  @IsOptional()
  @IsInt()
  @Min(0)
  maxDevices?: number | null;

  @IsOptional()
  @IsBoolean()
  isActive?: boolean;

  @IsOptional()
  @IsInt()
  sortOrder?: number;
}

export class UpdateSubscriptionPlanDto {
  @IsOptional()
  @IsString()
  @MaxLength(60)
  name?: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  price?: number;

  @IsOptional()
  @IsString()
  @MaxLength(10)
  currency?: string;

  @IsOptional()
  @IsInt()
  @Min(1)
  durationDays?: number | null;

  @IsOptional()
  @IsInt()
  @Min(1)
  durationMonths?: number | null;

  @IsOptional()
  @IsBoolean()
  isLifetime?: boolean;

  @IsOptional()
  @IsInt()
  @Min(0)
  verificationLimit?: number | null;

  @IsOptional()
  @IsInt()
  @Min(0)
  maxUsers?: number | null;

  @IsOptional()
  @IsInt()
  @Min(0)
  maxDevices?: number | null;

  @IsOptional()
  @IsBoolean()
  isActive?: boolean;

  @IsOptional()
  @IsInt()
  sortOrder?: number;
}
