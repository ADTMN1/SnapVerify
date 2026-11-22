import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import { Role } from '@prisma/client';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { SubscriptionService } from './subscription.service';
import { CreateSubscriptionCheckoutDto } from './dto/create-subscription-checkout.dto';
import { VerifySubscriptionCheckoutDto } from './dto/verify-subscription-checkout.dto';

interface AuthenticatedRequest {
  user: {
    sub: string;
    organizationId: string;
  };
}

@Controller('subscriptions')
@UseGuards(JwtAuthGuard, RolesGuard)
export class SubscriptionController {
  constructor(private readonly subscriptionService: SubscriptionService) {}

  @Get('plans')
  @Roles(Role.OWNER, Role.MANAGER, Role.CASHIER, Role.WAITER)
  getPlans() {
    return this.subscriptionService.getPlans();
  }

  @Get('current')
  @Roles(Role.OWNER, Role.MANAGER, Role.CASHIER, Role.WAITER)
  getCurrent(@Req() req: AuthenticatedRequest) {
    return this.subscriptionService.getCurrent(req.user.organizationId);
  }

  @Post('activate-free')
  @Roles(Role.OWNER)
  activateFree(@Req() req: AuthenticatedRequest) {
    return this.subscriptionService.activateFree(req.user.organizationId);
  }

  @Post('checkout')
  @Roles(Role.OWNER)
  createCheckout(
    @Body() dto: CreateSubscriptionCheckoutDto,
    @Req() req: AuthenticatedRequest,
  ) {
    return this.subscriptionService.createCheckout(
      req.user.sub,
      req.user.organizationId,
      dto.planId,
    );
  }

  @Get('checkout/:id')
  @Roles(Role.OWNER)
  getCheckout(@Param('id') id: string, @Req() req: AuthenticatedRequest) {
    return this.subscriptionService.getCheckout(id, req.user.organizationId);
  }

  @Post('checkout/:id/verify')
  @Roles(Role.OWNER)
  verifyCheckout(
    @Param('id') id: string,
    @Body() dto: VerifySubscriptionCheckoutDto,
    @Req() req: AuthenticatedRequest,
  ) {
    return this.subscriptionService.verifyCheckout(
      req.user.sub,
      req.user.organizationId,
      id,
      dto.referenceNumber,
    );
  }
}
