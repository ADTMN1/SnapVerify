import { IsNotEmpty, IsString, Matches } from 'class-validator';

export class VerifySubscriptionCheckoutDto {
  @IsString()
  @IsNotEmpty()
  @Matches(/^[A-Za-z0-9-]{6,64}$/, {
    message: 'Enter a valid Telebirr transaction reference',
  })
  referenceNumber: string;
}
