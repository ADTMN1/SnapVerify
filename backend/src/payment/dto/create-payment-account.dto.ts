import { IsString, IsNotEmpty, IsOptional, IsEnum } from 'class-validator';
import { PaymentProvider } from '@prisma/client';

export class CreatePaymentAccountDto {
  @IsEnum(PaymentProvider)
  @IsNotEmpty()
  provider: PaymentProvider;

  @IsOptional()
  @IsString()
  accountNumber?: string;

  @IsOptional()
  @IsString()
  suffix?: string;

  @IsOptional()
  @IsString()
  accountHolderName?: string;

  @IsOptional()
  @IsString()
  branchId?: string;
}
