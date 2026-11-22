import {
  BadGatewayException,
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import {
  CheckoutStatus,
  PaymentProvider,
  SubscriptionStatus,
} from '@prisma/client';
import { randomBytes } from 'crypto';
import { PrismaService } from '../prisma/prisma.service';
import { CheckEtService } from '../payment/check-et/check-et.service';
import { subscriptionDto, usagePeriodStart } from './subscription-usage';

const CHECKOUT_TTL_MINUTES = 30;

const PLANS = [
  {
    id: 'free',
    name: 'Free',
    price: 0,
    durationDays: null,
    verificationLimit: 20,
    maxUsers: 5,
    maxDevices: 10,
  },
  {
    id: 'one_month',
    name: '1 Month',
    price: 580,
    durationDays: 30,
    verificationLimit: null,
    maxUsers: null,
    maxDevices: null,
  },
  {
    id: 'three_months',
    name: '3 Months',
    price: 1500,
    durationDays: 90,
    verificationLimit: null,
    maxUsers: null,
    maxDevices: null,
  },
  {
    id: 'six_months',
    name: '6 Months',
    price: 3000,
    durationDays: 180,
    verificationLimit: null,
    maxUsers: null,
    maxDevices: null,
  },
  {
    id: 'one_year',
    name: '1 Year',
    price: 6000,
    durationDays: 360,
    verificationLimit: null,
    maxUsers: null,
    maxDevices: null,
  },
] as const;

@Injectable()
export class SubscriptionService {
  private readonly logger = new Logger(SubscriptionService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly checkEt: CheckEtService,
  ) {}

  getPlans() {
    return PLANS.map((plan) => ({
      ...plan,
      currency: 'ETB',
    }));
  }

  async getCurrent(organizationId: string) {
    const subscription = await this.prisma.subscription.findFirst({
      where: { organizationId },
      orderBy: { createdAt: 'desc' },
    });
    if (!subscription) return null;
    const usage = await this.prisma.subscriptionUsage.findUnique({
      where: {
        subscriptionId_periodStart: {
          subscriptionId: subscription.id,
          periodStart: usagePeriodStart(subscription),
        },
      },
    });
    return subscriptionDto(subscription, usage);
  }

  async activateFree(organizationId: string) {
    const plan = PLANS.find((p) => p.id === 'free');
    if (!plan) throw new BadRequestException('Unknown subscription plan');

    const now = new Date();
    const endDate = null;

    await this.prisma.$transaction([
      this.prisma.subscription.updateMany({
        where: { organizationId, status: SubscriptionStatus.ACTIVE },
        data: { status: SubscriptionStatus.EXPIRED },
      }),
      this.prisma.subscription.create({
        data: {
          organizationId,
          planName: plan.id,
          status: SubscriptionStatus.ACTIVE,
          startDate: now,
          endDate,
          maxUsers: plan.maxUsers,
          maxDevices: plan.maxDevices,
          verificationLimit: plan.verificationLimit,
        },
      }),
      this.prisma.organization.update({
        where: { id: organizationId },
        data: { subscriptionPlan: plan.id },
      }),
    ]);

    return this.getCurrent(organizationId);
  }

  async createCheckout(userId: string, organizationId: string, planId: string) {
    const plan = PLANS.find((p) => p.id === planId);
    if (!plan) throw new BadRequestException('Unknown subscription plan');

    const account = await this.platformAccount();
    const reference = `SV-SUB-${Date.now().toString(36).toUpperCase()}-${randomBytes(3).toString('hex').toUpperCase()}`;
    const expiresAt = new Date(Date.now() + CHECKOUT_TTL_MINUTES * 60_000);

    const checkout = await this.prisma.subscriptionCheckout.create({
      data: {
        organizationId,
        userId,
        planName: plan.id,
        amount: plan.price,
        provider: PaymentProvider.TELEBIRR,
        reference,
        expiresAt,
      },
    });

    this.logger.log(
      `Created subscription checkout ${checkout.id} plan=${plan.id}`,
    );
    return this.toCheckoutDto(checkout, account);
  }

  async getCheckout(id: string, organizationId: string) {
    const checkout = await this.prisma.subscriptionCheckout.findFirst({
      where: { id, organizationId },
    });
    if (!checkout) throw new NotFoundException('Checkout not found');
    const account = await this.platformAccount();
    return this.toCheckoutDto(checkout, account);
  }

  async verifyCheckout(
    userId: string,
    organizationId: string,
    id: string,
    referenceNumber: string,
  ) {
    const checkout = await this.prisma.subscriptionCheckout.findFirst({
      where: { id, organizationId, userId },
    });
    if (!checkout) throw new NotFoundException('Checkout not found');

    if (checkout.status === CheckoutStatus.PAID) {
      return {
        status: 'PAID',
        subscription: await this.getCurrent(organizationId),
      };
    }
    if (checkout.status !== CheckoutStatus.PENDING) {
      throw new BadRequestException('This checkout is no longer pending');
    }
    if (checkout.expiresAt.getTime() < Date.now()) {
      await this.prisma.subscriptionCheckout.update({
        where: { id: checkout.id },
        data: { status: CheckoutStatus.EXPIRED },
      });
      throw new BadRequestException('Checkout expired. Please start again.');
    }

    const account = await this.platformAccount();
    const normalizedReference = referenceNumber.trim().toUpperCase();
    const reused = await this.prisma.subscriptionCheckout.findFirst({
      where: {
        vendorReference: normalizedReference,
        id: { not: checkout.id },
      },
    });
    if (reused) {
      await this.markFailed(checkout.id);
      throw new BadRequestException(
        'This transaction reference was already used',
      );
    }

    let verification;
    try {
      verification = await this.checkEt.verifyReference(
        PaymentProvider.TELEBIRR,
        normalizedReference,
        account.accountNumber,
      );
    } catch (error) {
      this.logger.warn(
        `Subscription payment verification unavailable for checkout ${checkout.id}: ${error instanceof Error ? error.message : 'unknown error'}`,
      );
      throw new BadGatewayException(
        'Payment verification is unavailable right now. Try again shortly.',
      );
    }

    if (!verification.success) {
      await this.markFailed(checkout.id, normalizedReference);
      throw new BadRequestException(
        verification.message || 'Payment could not be verified',
      );
    }
    if (
      verification.provider &&
      verification.provider !== PaymentProvider.TELEBIRR
    ) {
      await this.markFailed(checkout.id, normalizedReference);
      throw new BadRequestException('Payment must be made with Telebirr');
    }
    if (
      verification.currency &&
      verification.currency.toUpperCase() !== checkout.currency.toUpperCase()
    ) {
      await this.markFailed(checkout.id, normalizedReference);
      throw new BadRequestException('Payment currency does not match the plan');
    }

    const paidAmount = this.parseAmount(verification.amount);
    if (paidAmount === null || paidAmount !== checkout.amount) {
      await this.markFailed(checkout.id, normalizedReference);
      throw new BadRequestException(
        `Payment amount must be ${checkout.amount} ${checkout.currency}`,
      );
    }

    if (
      !this.matchesPlatformAccount(
        verification.receiverAccount,
        verification.receiver,
        account,
      )
    ) {
      await this.markFailed(checkout.id, normalizedReference);
      throw new BadRequestException(
        'Payment was not sent to the SnapVerify subscription account',
      );
    }

    const plan = PLANS.find((p) => p.id === checkout.planName);
    if (!plan) throw new BadRequestException('Unknown subscription plan');

    const now = new Date();
    const endDate =
      plan.durationDays === null
        ? null
        : new Date(now.getTime() + plan.durationDays * 86_400_000);

    await this.prisma.$transaction([
      this.prisma.subscription.updateMany({
        where: { organizationId, status: SubscriptionStatus.ACTIVE },
        data: { status: SubscriptionStatus.EXPIRED },
      }),
      this.prisma.subscription.create({
        data: {
          organizationId,
          planName: plan.id,
          status: SubscriptionStatus.ACTIVE,
          startDate: now,
          endDate,
          maxUsers: plan.maxUsers,
          maxDevices: plan.maxDevices,
          verificationLimit: plan.verificationLimit,
        },
      }),
      this.prisma.organization.update({
        where: { id: organizationId },
        data: { subscriptionPlan: plan.id },
      }),
      this.prisma.subscriptionCheckout.update({
        where: { id: checkout.id },
        data: {
          status: CheckoutStatus.PAID,
          paidAt: now,
          vendorReference: normalizedReference,
        },
      }),
    ]);

    return {
      status: 'PAID',
      subscription: await this.getCurrent(organizationId),
    };
  }

  private async platformAccount() {
    const account = await this.prisma.platformPaymentAccount.findFirst({
      where: { provider: PaymentProvider.TELEBIRR, isActive: true },
      orderBy: { updatedAt: 'desc' },
    });
    if (!account) {
      throw new BadRequestException(
        'Subscription payment account is not configured. Contact support.',
      );
    }
    return {
      accountNumber: account.accountNumber,
      accountName: account.accountHolderName,
    };
  }

  private toCheckoutDto(
    checkout: {
      id: string;
      planName: string;
      amount: number;
      currency: string;
      provider: PaymentProvider;
      reference: string;
      status: CheckoutStatus;
      expiresAt: Date;
    },
    account: { accountNumber: string; accountName: string | null },
  ) {
    return {
      id: checkout.id,
      planName: checkout.planName,
      amount: checkout.amount,
      currency: checkout.currency,
      provider: checkout.provider,
      reference: checkout.reference,
      status: checkout.status,
      expiresAt: checkout.expiresAt.toISOString(),
      payTo: {
        provider: PaymentProvider.TELEBIRR,
        accountNumber: account.accountNumber,
        accountName: account.accountName,
      },
    };
  }

  private async markFailed(id: string, vendorReference?: string) {
    await this.prisma.subscriptionCheckout.updateMany({
      where: { id, status: CheckoutStatus.PENDING },
      data: {
        status: CheckoutStatus.FAILED,
        ...(vendorReference ? { vendorReference } : {}),
      },
    });
  }

  private parseAmount(value: string | number | null): number | null {
    if (value === null || value === undefined) return null;
    const amount = typeof value === 'number' ? value : Number.parseFloat(value);
    return Number.isFinite(amount) ? Math.round(amount * 100) / 100 : null;
  }

  private matchesPlatformAccount(
    receiverAccount: string | null,
    receiverName: string | null,
    account: { accountNumber: string; accountName: string | null },
  ): boolean {
    const raw = receiverAccount?.replace(/\s/g, '') ?? '';
    const tail = raw.match(/\*+(\d+)$/)?.[1];
    if (tail) {
      const stored = account.accountNumber.replace(/\s/g, '');
      const candidates = [stored];
      const local = stored.match(/^0([97]\d{8})$/);
      if (local) candidates.push(`251${stored.slice(1)}`);
      const international = stored.match(/^251([97]\d{8})$/);
      if (international) candidates.push(`0${international[1]}`);
      return candidates.some((candidate) => candidate.endsWith(tail));
    }

    if (account.accountName && receiverName) {
      const canonical = (value: string) =>
        value.toLowerCase().trim().replace(/\s+/g, ' ');
      return canonical(receiverName) === canonical(account.accountName);
    }

    return false;
  }
}
