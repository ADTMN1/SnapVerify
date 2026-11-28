import {
  IsBoolean,
  IsNotEmpty,
  IsOptional,
  IsString,
  Matches,
} from 'class-validator';

export class UpdateSubscriptionAccountDto {
  @IsString()
  @IsNotEmpty()
  @Matches(/^[0-9+\- ]{6,32}$/, {
    message: 'Enter a valid Telebirr account or phone number',
  })
  accountNumber: string;

  @IsOptional()
  @IsString()
  @IsNotEmpty()
  accountHolderName?: string;

  @IsOptional()
  @IsBoolean()
  isActive?: boolean;
}
