import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { PaymentStatus, Prisma } from '@prisma/client';

interface ListParams {
  search?: string;
  status?: string;
  page?: number;
  limit?: number;
}

function parsePaging(params: ListParams): {
  skip: number;
  take: number;
  page: number;
  limit: number;
} {
  const limit = Math.min(
    Math.max(parseInt(String(params.limit ?? '20'), 10) || 20, 1),
    100,
  );
  const page = Math.max(parseInt(String(params.page ?? '1'), 10) || 1, 1);
  return { skip: (page - 1) * limit, take: limit, page, limit };
}

/**
 * Platform-wide (super admin) operations. Unlike the owner-scoped admin
 * services, every query here spans ALL organizations.
 */
@Injectable()
export class PlatformAdminService {
  private readonly logger = new Logger(PlatformAdminService.name);

  constructor(private prisma: PrismaService) {}

  async getOverview() {
    const startOfToday = new Date();
    startOfToday.setHours(0, 0, 0, 0);

    const [
      totalOrganizations,
      activeOrganizations,
      totalUsers,
      totalPayments,
      totalBranches,
      verifiedPayments,
      pendingPayments,
      revenueAgg,
      todayRevenueAgg,
      todayTransactions,
      activeSubscriptions,
      recentOrganizations,
    ] = await Promise.all([
      this.prisma.organization.count(),
      this.prisma.organization.count({ where: { status: 'active' } }),
      this.prisma.user.count(),
      this.prisma.payment.count(),
      this.prisma.branch.count(),
      this.prisma.payment.count({ where: { status: PaymentStatus.VERIFIED } }),
      this.prisma.payment.count({ where: { status: PaymentStatus.PENDING } }),
      this.prisma.payment.aggregate({
        _sum: { amount: true },
        where: { status: PaymentStatus.VERIFIED },
      }),
      this.prisma.payment.aggregate({
        _sum: { amount: true },
        where: {
          status: PaymentStatus.VERIFIED,
          createdAt: { gte: startOfToday },
        },
      }),
      this.prisma.payment.count({
        where: { createdAt: { gte: startOfToday } },
      }),
      this.prisma.subscription.count({ where: { status: 'ACTIVE' } }),
      this.prisma.organization.findMany({
        orderBy: { createdAt: 'desc' },
        take: 5,
        include: {
          _count: {
            select: { userAssignments: true, payments: true, branches: true },
          },
        },
      }),
    ]);

    return {
      totalOrganizations,
      activeOrganizations,
      totalUsers,
      totalPayments,
      totalBranches,
      verifiedPayments,
      pendingPayments,
      totalRevenue: Number(revenueAgg._sum.amount ?? 0),
      todayRevenue: Number(todayRevenueAgg._sum.amount ?? 0),
      todayTransactions,
      activeSubscriptions,
      recentOrganizations,
    };
  }

  async listOrganizations(params: ListParams) {
    const { skip, take, page, limit } = parsePaging(params);
    const where: Prisma.OrganizationWhereInput = {
      ...(params.status ? { status: params.status } : {}),
      ...(params.search
        ? {
            OR: [
              { name: { contains: params.search, mode: 'insensitive' } },
              { email: { contains: params.search, mode: 'insensitive' } },
              { phone: { contains: params.search, mode: 'insensitive' } },
            ],
          }
        : {}),
    };

    const [data, total] = await Promise.all([
      this.prisma.organization.findMany({
        where,
        skip,
        take,
        orderBy: { createdAt: 'desc' },
        include: {
          _count: {
            select: {
              userAssignments: true,
              payments: true,
              branches: true,
              paymentAccounts: true,
            },
          },
          subscriptions: { orderBy: { createdAt: 'desc' }, take: 1 },
        },
      }),
      this.prisma.organization.count({ where }),
    ]);

    return { data, total, page, limit };
  }

  async getOrganization(id: string) {
    const org = await this.prisma.organization.findUnique({
      where: { id },
      include: {
        _count: {
          select: {
            userAssignments: true,
            payments: true,
            branches: true,
            paymentAccounts: true,
          },
        },
        branches: true,
        subscriptions: { orderBy: { createdAt: 'desc' }, take: 1 },
        userAssignments: {
          include: {
            user: {
              select: {
                id: true,
                fullName: true,
                email: true,
                phone: true,
                status: true,
              },
            },
          },
        },
      },
    });
    if (!org) throw new NotFoundException('Organization not found');
    return org;
  }

  async updateOrganization(
    id: string,
    data: { status?: string; subscriptionPlan?: string },
  ) {
    const existing = await this.prisma.organization.findUnique({
      where: { id },
    });
    if (!existing) throw new NotFoundException('Organization not found');

    return this.prisma.organization.update({
      where: { id },
      data: {
        ...(data.status ? { status: data.status } : {}),
        ...(data.subscriptionPlan !== undefined
          ? { subscriptionPlan: data.subscriptionPlan }
          : {}),
      },
    });
  }

  async listUsers(params: ListParams) {
    const { skip, take, page, limit } = parsePaging(params);
    const where: Prisma.UserWhereInput = {
      ...(params.status ? { status: params.status } : {}),
      ...(params.search
        ? {
            OR: [
              { fullName: { contains: params.search, mode: 'insensitive' } },
              { email: { contains: params.search, mode: 'insensitive' } },
              { phone: { contains: params.search, mode: 'insensitive' } },
            ],
          }
        : {}),
    };

    const [data, total] = await Promise.all([
      this.prisma.user.findMany({
        where,
        skip,
        take,
        orderBy: { createdAt: 'desc' },
        include: {
          userAssignments: {
            include: { organization: { select: { id: true, name: true } } },
          },
        },
      }),
      this.prisma.user.count({ where }),
    ]);

    // Never expose password hashes.
    const sanitized = data.map(({ passwordHash, ...u }) => ({
      ...u,
      hasPassword: Boolean(passwordHash),
    }));
    return { data: sanitized, total, page, limit };
  }

  async updateUser(
    id: string,
    data: { status?: string; isPlatformAdmin?: boolean },
  ) {
    const existing = await this.prisma.user.findUnique({ where: { id } });
    if (!existing) throw new NotFoundException('User not found');

    return this.prisma.user.update({
      where: { id },
      data: {
        ...(data.status ? { status: data.status } : {}),
        ...(data.isPlatformAdmin !== undefined
          ? { isPlatformAdmin: data.isPlatformAdmin }
          : {}),
      },
      select: {
        id: true,
        fullName: true,
        email: true,
        phone: true,
        status: true,
        isPlatformAdmin: true,
        createdAt: true,
      },
    });
  }

  async listSubscriptions(params: ListParams) {
    const { skip, take, page, limit } = parsePaging(params);
    const [data, total] = await Promise.all([
      this.prisma.subscription.findMany({
        skip,
        take,
        orderBy: { createdAt: 'desc' },
        include: { organization: { select: { id: true, name: true } } },
      }),
      this.prisma.subscription.count(),
    ]);
    return { data, total, page, limit };
  }

  async listPayments(params: ListParams) {
    const { skip, take, page, limit } = parsePaging(params);
    const status = params.status as PaymentStatus | undefined;
    const where: Prisma.PaymentWhereInput = {
      ...(status ? { status } : {}),
      ...(params.search
        ? {
            OR: [
              {
                transactionId: { contains: params.search, mode: 'insensitive' },
              },
              { senderName: { contains: params.search, mode: 'insensitive' } },
            ],
          }
        : {}),
    };

    const [data, total, revenueAgg] = await Promise.all([
      this.prisma.payment.findMany({
        where,
        skip,
        take,
        orderBy: { createdAt: 'desc' },
        include: { organization: { select: { id: true, name: true } } },
      }),
      this.prisma.payment.count({ where }),
      this.prisma.payment.aggregate({ _sum: { amount: true }, where }),
    ]);

    return {
      data,
      total,
      page,
      limit,
      totalAmount: Number(revenueAgg._sum.amount ?? 0),
    };
  }

  async listActivity(limit = 50) {
    return this.prisma.activityLog.findMany({
      take: Math.min(Math.max(limit, 1), 200),
      orderBy: { createdAt: 'desc' },
      include: {
        user: { select: { id: true, fullName: true, email: true } },
        organization: { select: { id: true, name: true } },
      },
    });
  }
}
