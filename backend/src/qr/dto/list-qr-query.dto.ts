import { IsOptional, IsString, MaxLength } from 'class-validator';

/**
 * Query parameters for GET /qr.
 *
 * Values stay strings at this layer (the global ValidationPipe does not
 * transform); QrService coerces and validates `provider` / `isActive` so an
 * invalid filter is rejected instead of silently ignored.
 */
export class ListQrQueryDto {
  @IsOptional()
  @IsString()
  branchId?: string;

  @IsOptional()
  @IsString()
  provider?: string;

  @IsOptional()
  @IsString()
  isActive?: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  search?: string;
}
