import { BadRequestException, Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;
const DAY_MS = 24 * 60 * 60 * 1000;

interface ReportQuery {
  organizationId: string;
  userId?: string;
  role?: string;
  from?: string;
  to?: string;
}

interface PaymentRow {
  id: string;
  amount: unknown;
  currency: string;
  status: string;
  paymentMethod: string | null;
  transactionId: string;
  senderName: string | null;
  receiverName: string | null;
  riskScore: number | null;
  createdAt: Date;
  userId: string | null;
  user: {
    id: string;
    fullName: string | null;
    username: string | null;
    phone: string | null;
  } | null;
}

/**
 * Real, database-backed reporting for the current organization.
 *
 * All queries are organization-scoped. Cashiers and waiters only see their own
 * activity (matching the verification-history access rule); owners and managers
 * see the whole organization. No data is ever fabricated.
 */
@Injectable()
export class ReportsService {
  constructor(private prisma: PrismaService) {}

  async getSummary(query: ReportQuery) {
    const { from, to, fromStr, toStr } = this.resolveRange(
      query.from,
      query.to,
    );

    const where: any = {
      organizationId: query.organizationId,
      createdAt: { gte: from, lt: to },
    };
    // Role scoping: cashiers/waiters see only their own verifications.
    if (query.role !== 'OWNER' && query.role !== 'MANAGER' && query.userId) {
      where.userId = query.userId;
    }

    const payments = (await this.prisma.payment.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      select: {
        id: true,
        amount: true,
        currency: true,
        status: true,
        paymentMethod: true,
        transactionId: true,
        senderName: true,
        receiverName: true,
        riskScore: true,
        createdAt: true,
        userId: true,
        user: {
          select: { id: true, fullName: true, username: true, phone: true },
        },
      },
    })) as unknown as PaymentRow[];

    return this.buildSummary(payments, fromStr, toStr);
  }

  private resolveRange(fromStr?: string, toStr?: string) {
    const today = this.startOfDay(new Date());
    const end = toStr ? this.parseDate(toStr, 'to') : today;
    const start = fromStr ? this.parseDate(fromStr, 'from') : end;
    if (start.getTime() > end.getTime()) {
      throw new BadRequestException('"from" must be on or before "to".');
    }
    return {
      from: start,
      // Exclusive upper bound: include the whole "to" day.
      to: new Date(end.getTime() + DAY_MS),
      fromStr: this.formatDate(start),
      toStr: this.formatDate(end),
    };
  }

  private parseDate(value: string, field: string): Date {
    if (!DATE_RE.test(value)) {
      throw new BadRequestException(
        `Invalid "${field}" date. Expected YYYY-MM-DD.`,
      );
    }
    const parsed = new Date(`${value}T00:00:00.000Z`);
    if (Number.isNaN(parsed.getTime())) {
      throw new BadRequestException(`Invalid "${field}" date.`);
    }
    return parsed;
  }

  private startOfDay(date: Date): Date {
    return new Date(
      Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()),
    );
  }

  private formatDate(date: Date): string {
    return date.toISOString().slice(0, 10);
  }

  private buildSummary(payments: PaymentRow[], fromStr: string, toStr: string) {
    const statusMap = new Map<string, { count: number; amount: number }>();
    const providerMap = new Map<string, { count: number; amount: number }>();
    const staffMap = new Map<
      string,
      { count: number; amount: number; name: string }
    >();
    const dailyMap = new Map<
      string,
      {
        count: number;
        amount: number;
        verifiedCount: number;
        verifiedAmount: number;
      }
    >();

    let totalAmount = 0;
    let verifiedCount = 0;
    let verifiedAmount = 0;
    let failedCount = 0;
    let rejectedCount = 0;
    let pendingCount = 0;
    let highRiskCount = 0;
    let highRiskAmount = 0;
    const highRiskPayments: ReturnType<ReportsService['toPaymentRow']>[] = [];
    const currency =
      payments.find((p) => p.currency && p.currency.length > 0)?.currency ??
      'ETB';

    for (const p of payments) {
      const amount = Number(p.amount) || 0;
      const status = p.status ?? 'UNKNOWN';
      totalAmount += amount;

      const statusRow = statusMap.get(status) ?? { count: 0, amount: 0 };
      statusRow.count += 1;
      statusRow.amount += amount;
      statusMap.set(status, statusRow);

      const provider = p.paymentMethod || 'unknown';
      const providerRow = providerMap.get(provider) ?? { count: 0, amount: 0 };
      providerRow.count += 1;
      providerRow.amount += amount;
      providerMap.set(provider, providerRow);

      const staffKey = p.userId ?? 'unassigned';
      const staffName =
        p.user?.fullName || p.user?.username || p.user?.phone || 'Unknown';
      const staffRow = staffMap.get(staffKey) ?? {
        count: 0,
        amount: 0,
        name: staffName,
      };
      staffRow.count += 1;
      staffRow.amount += amount;
      staffMap.set(staffKey, staffRow);

      const day = p.createdAt.toISOString().slice(0, 10);
      const dailyRow = dailyMap.get(day) ?? {
        count: 0,
        amount: 0,
        verifiedCount: 0,
        verifiedAmount: 0,
      };
      dailyRow.count += 1;
      dailyRow.amount += amount;
      if (status === 'VERIFIED') {
        dailyRow.verifiedCount += 1;
        dailyRow.verifiedAmount += amount;
      }
      dailyMap.set(day, dailyRow);

      if (status === 'VERIFIED') {
        verifiedCount += 1;
        verifiedAmount += amount;
      } else if (status === 'FAILED') {
        failedCount += 1;
      } else if (status === 'REJECTED') {
        rejectedCount += 1;
      } else if (status === 'PENDING') {
        pendingCount += 1;
      }

      if ((p.riskScore ?? 0) >= 50) {
        highRiskCount += 1;
        highRiskAmount += amount;
        highRiskPayments.push(this.toPaymentRow(p));
      }
    }

    return {
      range: { from: fromStr, to: toStr },
      summary: {
        total: payments.length,
        verified: verifiedCount,
        failed: failedCount,
        rejected: rejectedCount,
        pending: pendingCount,
        totalAmount: this.round(totalAmount),
        verifiedAmount: this.round(verifiedAmount),
        averageAmount:
          verifiedCount > 0 ? this.round(verifiedAmount / verifiedCount) : 0,
        highRisk: highRiskCount,
        highRiskAmount: this.round(highRiskAmount),
        currency,
      },
      byStatus: [...statusMap.entries()]
        .map(([status, value]) => ({
          status,
          count: value.count,
          amount: this.round(value.amount),
        }))
        .sort((a, b) => b.count - a.count),
      byProvider: [...providerMap.entries()]
        .map(([provider, value]) => ({
          provider,
          count: value.count,
          amount: this.round(value.amount),
        }))
        .sort((a, b) => b.count - a.count),
      byStaff: [...staffMap.entries()]
        .map(([userId, value]) => ({
          userId,
          name: value.name,
          count: value.count,
          amount: this.round(value.amount),
        }))
        .sort((a, b) => b.count - a.count),
      daily: [...dailyMap.entries()]
        .sort(([a], [b]) => a.localeCompare(b))
        .map(([date, value]) => ({
          date,
          count: value.count,
          amount: this.round(value.amount),
          verifiedCount: value.verifiedCount,
          verifiedAmount: this.round(value.verifiedAmount),
        })),
      recent: payments.slice(0, 10).map((p) => this.toPaymentRow(p)),
      highRiskPayments: highRiskPayments.slice(0, 10),
    };
  }

  private toPaymentRow(p: PaymentRow) {
    return {
      id: p.id,
      amount: Number(p.amount) || 0,
      currency: p.currency,
      status: p.status,
      paymentMethod: p.paymentMethod,
      transactionId: p.transactionId,
      senderName: p.senderName,
      receiverName: p.receiverName,
      riskScore: p.riskScore,
      createdAt: p.createdAt.toISOString(),
      verifiedBy: p.user
        ? {
            id: p.user.id,
            name: p.user.fullName || p.user.username || 'Unknown',
          }
        : null,
    };
  }

  private round(value: number): number {
    return Math.round(value * 100) / 100;
  }
}