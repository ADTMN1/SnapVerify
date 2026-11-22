import { IsIn, IsNotEmpty, IsString } from 'class-validator';

export const SUBSCRIPTION_PLAN_IDS = [
  'one_month',
  'three_months',
  'six_months',
  'one_year',
] as const;

export class CreateSubscriptionCheckoutDto {
  @IsString()
  @IsNotEmpty()
  @IsIn(SUBSCRIPTION_PLAN_IDS)
  planId: string;
}
