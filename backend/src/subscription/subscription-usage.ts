import { Subscription, SubscriptionUsage } from '@prisma/client';

export function usagePeriodStart(subscription: { startDate: Date }): Date {
  return new Date(subscription.startDate);
}

export function subscriptionDto(
  subscription: Subscription,
  usage?: SubscriptionUsage | null,
) {
  const limit = subscription.verificationLimit ?? null;
  const used = usage?.count ?? 0;
  return {
    ...subscription,
    verificationLimit: limit,
    verificationUsed: used,
    verificationRemaining: limit === null ? null : Math.max(0, limit - used),
    usagePeriodStart: usagePeriodStart(subscription).toISOString(),
    usagePeriodEnd: null,
  };
}
