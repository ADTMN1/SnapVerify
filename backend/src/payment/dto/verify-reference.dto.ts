import { IsNotEmpty, IsString, IsOptional, IsNumber } from 'class-validator';

export class VerifyReferenceDto {
  @IsString()
  @IsNotEmpty()
  referenceNumber: string;

  @IsOptional()
  @IsNumber()
  amount?: number;

  @IsOptional()
  @IsString()
  provider?: string;

  @IsOptional()
  @IsString()
  suffix?: string;
}
