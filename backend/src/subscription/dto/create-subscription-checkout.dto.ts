import { IsNotEmpty, IsString, MaxLength } from 'class-validator';

export class CreateSubscriptionCheckoutDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(60)
  planId: string;
}
