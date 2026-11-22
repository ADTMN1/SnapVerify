import {
  BadGatewayException,
  BadRequestException,
  Injectable,
  HttpException,
  HttpStatus,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import {
  CheckoutStatus,
  PaymentProvider,
  Prisma,
  SubscriptionStatus,
} from '@prisma/client';
import { randomBytes } from 'crypto';
import { PrismaService } from '../prisma/prisma.service';
import {
  CheckEtService,
  isStrictCheckEtSuccess,
  NormalizedVerification,
} from '../payment/check-et/check-et.service';
import { UpstreamVerificationUnavailableError } from '../payment/payment-provider-errors';
import {
  ProviderError,
  RETRYABLE_PROVIDER_ERRORS,
} from '../payment/provider-error';
import { subscriptionDto, usagePeriodStart } from './subscription-usage';

const CHECKOUT_TTL_MINUTES = 30;
const VERIFY_RATE_LIMIT_WINDOW_MS = 5 * 60 * 1000;
const VERIFY_RATE_LIMIT_MAX = 10;

function normalizeVendorReference(value: string): string {
  return value.trim().toUpperCase().replace(/\s+/g, '');
}

function maskReference(value: string): string {
  if (value.length <= 4) return '****';
  return `${value.slice(0, 2)}****${value.slice(-2)}`;
}

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
    const checkout = await this.loadCheckout(userId, organizationId, id);
    if (checkout.status === CheckoutStatus.PAID) {
      return this.paidResult(organizationId);
    }

    await this.assertVerificationRateLimit(
      userId,
      organizationId,
      checkout.id,
      'reference',
    );

    const account = await this.platformAccount();
    const vendorReference = normalizeVendorReference(referenceNumber);
    if (vendorReference !== normalizeVendorReference(checkout.reference)) {
      throw new BadRequestException(
        'Use the payment reference shown for this checkout.',
      );
    }

    let verification: NormalizedVerification;
    try {
      verification = await this.checkEt.verifyReference(
        PaymentProvider.TELEBIRR,
        vendorReference,
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

    return this.completeVerification(
      checkout,
      userId,
      organizationId,
      account,
      verification,
      vendorReference,
    );
  }

  async verifyCheckoutByImage(
    userId: string,
    organizationId: string,
    id: string,
    file: Express.Multer.File,
    receiptText?: string,
  ) {
    const checkout = await this.loadCheckout(userId, organizationId, id);
    if (checkout.status === CheckoutStatus.PAID) {
      return this.paidResult(organizationId);
    }

    await this.assertVerificationRateLimit(
      userId,
      organizationId,
      checkout.id,
      'image',
    );

    const account = await this.platformAccount();
    const normalizedMime = (file.mimetype || '').toLowerCase();

    let verification: NormalizedVerification;
    try {
      verification = await this.checkEt.verifyReceiptFile({
        file: file.buffer,
        filename: file.originalname || 'receipt.jpg',
        contentType: normalizedMime || 'image/jpeg',
        receiptText: receiptText?.slice(0, 50_000),
      });
    } catch (error) {
      const message = error instanceof Error ? error.message : 'unknown error';
      this.logger.warn(
        `Subscription receipt verification failed for checkout ${checkout.id}: ${message}`,
      );
      if (
        error instanceof ProviderError &&
        RETRYABLE_PROVIDER_ERRORS.has(error.type)
      ) {
        throw new BadGatewayException(
          'Payment verification is unavailable right now. Try again shortly.',
        );
      }
      if (error instanceof UpstreamVerificationUnavailableError) {
        throw new BadRequestException(error.message);
      }
      throw new BadRequestException(
        'The receipt could not be verified. Make sure the full receipt is visible and readable.',
      );
    }

    const vendorReference = normalizeVendorReference(
      verification.transactionNumber ?? verification.verificationId ?? '',
    );

    return this.completeVerification(
      checkout,
      userId,
      organizationId,
      account,
      verification,
      vendorReference,
    );
  }

  private async loadCheckout(
    userId: string,
    organizationId: string,
    id: string,
  ) {
    const checkout = await this.prisma.subscriptionCheckout.findFirst({
      where: { id, organizationId, userId },
    });
    if (!checkout) throw new NotFoundException('Checkout not found');

    if (checkout.status === CheckoutStatus.PAID) return checkout;
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
    return checkout;
  }

  private async paidResult(organizationId: string) {
    return {
      status: 'PAID',
      subscription: await this.getCurrent(organizationId),
    };
  }

  private async completeVerification(
    checkout: {
      id: string;
      status: CheckoutStatus;
      currency: string;
      amount: number;
      planName: string;
      reference: string;
    },
    userId: string,
    organizationId: string,
    account: { accountNumber: string; accountName: string | null },
    verification: NormalizedVerification,
    vendorReference: string,
  ) {
    const receiptReference = normalizeVendorReference(
      verification.transactionNumber ??
        verification.verificationId ??
        vendorReference,
    );
    if (verification.duplicate) {
      await this.markFailed(checkout.id);
      throw new BadRequestException('This receipt has already been used');
    }
    if (!verification.success || !isStrictCheckEtSuccess(verification.raw)) {
      await this.markFailed(checkout.id);
      throw new BadRequestException(
        verification.message ||
          'Payment is not confirmed as successful. Use a completed Telebirr receipt.',
      );
    }
    if (!receiptReference) {
      await this.markFailed(checkout.id);
      throw new BadRequestException(
        'Receipt reference could not be read. Use a clearer screenshot.',
      );
    }
    if (
      verification.provider &&
      verification.provider !== PaymentProvider.TELEBIRR
    ) {
      await this.markFailed(checkout.id);
      throw new BadRequestException('Payment must be made with Telebirr');
    }
    if (
      verification.currency &&
      verification.currency.toUpperCase() !== checkout.currency.toUpperCase()
    ) {
      await this.markFailed(checkout.id);
      throw new BadRequestException('Payment currency does not match the plan');
    }

    const paidAmount = this.parseAmount(verification.amount);
    if (paidAmount === null || paidAmount !== checkout.amount) {
      await this.markFailed(checkout.id);
      throw new BadRequestException(
        `Payment amount must be ${checkout.amount} ${checkout.currency}`,
      );
    }

    const accountMatch = this.matchesPlatformAccount(
      verification.receiverAccount,
      verification.receiver,
      account,
    );
    if (accountMatch === 'mismatch') {
      await this.markFailed(checkout.id);
      throw new BadRequestException(
        'Payment was not sent to the SnapVerify subscription account',
      );
    }
    if (accountMatch === 'needs_review') {
      await this.markFailed(checkout.id);
      await this.logVerificationEvent(
        organizationId,
        userId,
        'SUBSCRIPTION_PAYMENT_NEEDS_REVIEW',
        checkout.id,
        receiptReference,
      );
      throw new BadRequestException(
        'Payment needs manual review. Contact support with your receipt.',
      );
    }

    const reused = await this.prisma.subscriptionCheckout.findFirst({
      where: {
        vendorReference: receiptReference,
        id: { not: checkout.id },
      },
    });
    if (reused) {
      await this.markFailed(checkout.id);
      throw new BadRequestException(
        'This transaction reference was already used',
      );
    }

    const plan = PLANS.find((p) => p.id === checkout.planName);
    if (!plan) throw new BadRequestException('Unknown subscription plan');

    const now = new Date();
    const endDate =
      plan.durationDays === null
        ? null
        : new Date(now.getTime() + plan.durationDays * 86_400_000);

    try {
      await this.prisma.$transaction(async (tx) => {
        await tx.paymentReceiptUsage.create({
          data: {
            provider: PaymentProvider.TELEBIRR,
            normalizedReference: receiptReference,
            source: 'subscription_checkout',
            organizationId,
            checkoutId: checkout.id,
          },
        });
        await tx.subscription.updateMany({
          where: { organizationId, status: SubscriptionStatus.ACTIVE },
          data: { status: SubscriptionStatus.EXPIRED },
        });
        await tx.subscription.create({
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
        });
        await tx.organization.update({
          where: { id: organizationId },
          data: { subscriptionPlan: plan.id },
        });
        await tx.subscriptionCheckout.update({
          where: { id: checkout.id },
          data: {
            status: CheckoutStatus.PAID,
            paidAt: now,
            vendorReference: receiptReference,
          },
        });
        await tx.activityLog.create({
          data: {
            organizationId,
            userId,
            action: 'SUBSCRIPTION_PAYMENT_VERIFIED',
            metadata: {
              checkoutId: checkout.id,
              planName: plan.id,
              reference: maskReference(receiptReference),
            },
          },
        });
      });
    } catch (error) {
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === 'P2002'
      ) {
        await this.markFailed(checkout.id);
        throw new BadRequestException('This receipt has already been used');
      }
      throw error;
    }

    return this.paidResult(organizationId);
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

  private async markFailed(id: string) {
    await this.prisma.subscriptionCheckout.updateMany({
      where: { id, status: CheckoutStatus.PENDING },
      data: { status: CheckoutStatus.FAILED },
    });
  }

  private parseAmount(value: string | number | null): number | null {
    if (value === null || value === undefined) return null;
    const amount = typeof value === 'number' ? value : Number.parseFloat(value);
    return Number.isFinite(amount) ? Math.round(amount * 100) / 100 : null;
  }

  private async assertVerificationRateLimit(
    userId: string,
    organizationId: string,
    checkoutId: string,
    method: 'reference' | 'image',
  ) {
    const since = new Date(Date.now() - VERIFY_RATE_LIMIT_WINDOW_MS);
    const attempts = await this.prisma.activityLog.count({
      where: {
        organizationId,
        userId,
        action: 'SUBSCRIPTION_PAYMENT_VERIFY_ATTEMPT',
        createdAt: { gte: since },
      },
    });
    if (attempts >= VERIFY_RATE_LIMIT_MAX) {
      throw new HttpException(
        'Too many verification attempts. Try again in a few minutes.',
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }
    await this.logVerificationEvent(
      organizationId,
      userId,
      'SUBSCRIPTION_PAYMENT_VERIFY_ATTEMPT',
      checkoutId,
      undefined,
      { method },
    );
  }

  private async logVerificationEvent(
    organizationId: string,
    userId: string,
    action: string,
    checkoutId: string,
    reference?: string,
    extra: Record<string, unknown> = {},
  ) {
    await this.prisma.activityLog.create({
      data: {
        organizationId,
        userId,
        action,
        metadata: {
          checkoutId,
          ...(reference ? { reference: maskReference(reference) } : {}),
          ...extra,
        },
      },
    });
  }

  private matchesPlatformAccount(
    receiverAccount: string | null,
    receiverName: string | null,
    account: { accountNumber: string; accountName: string | null },
  ): 'matched' | 'needs_review' | 'mismatch' {
    const canonical = (value: string) =>
      value.toLowerCase().trim().replace(/\s+/g, ' ');
    const phone = (value: string) => {
      const digits = value.replace(/\D/g, '');
      if (/^0[97]\d{8}$/.test(digits)) return `251${digits.slice(1)}`;
      return digits;
    };

    const stored = phone(account.accountNumber);
    const receiver = receiverAccount ? phone(receiverAccount) : '';
    const maskedTail = receiverAccount?.match(/\*+(\d{3,})$/)?.[1];
    const nameMatches = Boolean(
      account.accountName &&
        receiverName &&
        canonical(account.accountName) === canonical(receiverName),
    );

    if (receiver && receiver === stored) return 'matched';
    if (maskedTail) {
      return stored.endsWith(maskedTail) && nameMatches
        ? 'matched'
        : 'mismatch';
    }
    if (receiver || (receiverName && nameMatches)) return 'needs_review';
    return 'mismatch';
  }
}
