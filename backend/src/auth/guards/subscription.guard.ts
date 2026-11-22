import {
  CanActivate,
  ExecutionContext,
  Injectable,
  ForbiddenException,
  Logger,
} from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { SubscriptionStatus } from '@prisma/client';
import { usagePeriodStart } from '../../subscription/subscription-usage';

/**
 * Checks that the user's current organization has an active subscription.
 * Must be used AFTER JwtAuthGuard so req.user.organizationId is populated.
 */
@Injectable()
export class SubscriptionGuard implements CanActivate {
  private readonly logger = new Logger(SubscriptionGuard.name);

  constructor(private prisma: PrismaService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const { user } = context.switchToHttp().getRequest();

    if (!user?.organizationId) {
      throw new ForbiddenException('No organization context');
    }

    const subscription = await this.prisma.subscription.findFirst({
      where: {
        organizationId: user.organizationId,
        status: SubscriptionStatus.ACTIVE,
        OR: [{ endDate: null }, { endDate: { gt: new Date() } }],
      },
      orderBy: { createdAt: 'desc' },
    });

    if (!subscription) {
      this.logger.warn(
        `Blocked access: org=${user.organizationId} has no active subscription`,
      );
      throw new ForbiddenException(
        'Subscription expired. Please renew your subscription to continue.',
      );
    }

    if (subscription.verificationLimit !== null) {
      const usage = await this.prisma.subscriptionUsage.findUnique({
        where: {
          subscriptionId_periodStart: {
            subscriptionId: subscription.id,
            periodStart: usagePeriodStart(subscription),
          },
        },
      });
      if ((usage?.count ?? 0) >= subscription.verificationLimit) {
        throw new ForbiddenException(
          `Verification limit reached (${subscription.verificationLimit}). Upgrade your plan to continue.`,
        );
      }
    }

    return true;
  }
}
