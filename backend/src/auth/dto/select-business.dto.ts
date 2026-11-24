import { IsBoolean, IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class SelectBusinessDto {
  @IsString()
  @IsNotEmpty({ message: 'Business selection token is required.' })
  selectionToken: string;

  @IsString()
  @IsNotEmpty({ message: 'Organization is required.' })
  organizationId: string;

  @IsBoolean()
  @IsOptional()
  rememberMe?: boolean;
}
