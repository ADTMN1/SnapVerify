import { BadRequestException } from '@nestjs/common';

const MILLISECONDS_PER_DAY = 86_400_000;

export interface PlanDurationFields {
  durationDays?: number | null;
  durationMonths?: number | null;
  isLifetime?: boolean;
}

export function addCalendarMonths(date: Date, months: number): Date {
  const result = new Date(
    Date.UTC(
      date.getUTCFullYear(),
      date.getUTCMonth() + months,
      1,
      date.getUTCHours(),
      date.getUTCMinutes(),
      date.getUTCSeconds(),
      date.getUTCMilliseconds(),
    ),
  );
  const lastDay = new Date(
    Date.UTC(result.getUTCFullYear(), result.getUTCMonth() + 1, 0),
  ).getUTCDate();
  result.setUTCDate(Math.min(date.getUTCDate(), lastDay));
  return result;
}

export function calculateEndDate(
  plan: PlanDurationFields,
  now = new Date(),
): Date | null {
  if (plan.isLifetime === true) return null;
  if (plan.durationMonths != null && plan.durationMonths > 0) {
    return addCalendarMonths(now, plan.durationMonths);
  }
  if (plan.durationDays != null && plan.durationDays > 0) {
    return new Date(now.getTime() + plan.durationDays * MILLISECONDS_PER_DAY);
  }
  return null;
}

export function validatePlanDuration(plan: PlanDurationFields): void {
  if (plan.isLifetime === true) {
    if (plan.durationDays != null || plan.durationMonths != null) {
      throw new BadRequestException(
        'Lifetime plans cannot have a duration',
      );
    }
    return;
  }

  if (plan.durationDays != null && plan.durationMonths != null) {
    throw new BadRequestException(
      'Use either durationDays or durationMonths, not both',
    );
  }

  if (plan.durationMonths != null) {
    if (
      !Number.isInteger(plan.durationMonths) ||
      plan.durationMonths <= 0
    ) {
      throw new BadRequestException('durationMonths must be greater than 0');
    }
    return;
  }

  if (plan.durationDays != null) {
    if (!Number.isInteger(plan.durationDays) || plan.durationDays <= 0) {
      throw new BadRequestException('durationDays must be greater than 0');
    }
    return;
  }

  throw new BadRequestException(
    'A duration is required unless the plan is explicitly configured as lifetime',
  );
}
