import {
  Controller,
  Get,
  Post,
  Put,
  Delete,
  Body,
  Req,
  UseGuards,
  Param,
  Query,
} from '@nestjs/common';
import { Role } from '@prisma/client';
import { PaymentAccountService } from './payment-account.service';
import { CreatePaymentAccountDto } from './dto/create-payment-account.dto';
import { UpdatePaymentAccountDto } from './dto/update-payment-account.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { BranchGuard } from '../auth/guards/branch.guard';
import { Roles } from '../auth/decorators/roles.decorator';

@Controller('payment-accounts')
@UseGuards(JwtAuthGuard, RolesGuard, BranchGuard)
export class PaymentAccountController {
  constructor(private paymentAccountService: PaymentAccountService) {}

  @Post()
  @Roles(Role.OWNER)
  create(@Body() dto: CreatePaymentAccountDto, @Req() req: any) {
    const { organizationId } = req.user;
    return this.paymentAccountService.create(organizationId, dto);
  }

  @Get()
  @Roles(Role.OWNER)
  findAll(@Req() req: any, @Query('branchId') branchId?: string) {
    const { organizationId } = req.user;
    if (branchId) {
      return this.paymentAccountService.findByOrganizationAndBranch(
        organizationId,
        branchId,
      );
    }
    return this.paymentAccountService.findAll(organizationId);
  }

  @Get(':provider')
  @Roles(Role.OWNER)
  findOne(
    @Param('provider') provider: string,
    @Req() req: any,
    @Query('branchId') branchId?: string,
  ) {
    const { organizationId } = req.user;
    return this.paymentAccountService.findByProviderAndBranch(
      organizationId,
      provider as any,
      branchId,
    );
  }

  @Put(':provider')
  @Roles(Role.OWNER)
  update(
    @Param('provider') provider: string,
    @Body() dto: UpdatePaymentAccountDto,
    @Req() req: any,
    @Query('branchId') branchId?: string,
  ) {
    const { organizationId } = req.user;
    return this.paymentAccountService.update(
      organizationId,
      provider as any,
      branchId,
      dto,
    );
  }

  @Delete(':provider')
  @Roles(Role.OWNER)
  remove(
    @Param('provider') provider: string,
    @Req() req: any,
    @Query('branchId') branchId?: string,
  ) {
    const { organizationId } = req.user;
    return this.paymentAccountService.remove(
      organizationId,
      provider as any,
      branchId,
    );
  }
}
