import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

export interface DashboardStats {
  totalVerified: number;
  totalPending: number;
  totalFailed: number;
  fraudAlerts: number;
  todayRevenue: number;
  todayTransactions: number;
  activeEmployees: number;
  activeBranches: number;
}

@Injectable()
export class AdminDashboardService {
  private readonly logger = new Logger(AdminDashboardService.name);

  constructor(private prisma: PrismaService) {}

  /**
   * Get dashboard statistics for an organization.
   */
  async getDashboardStats(organizationId: string): Promise<DashboardStats> {
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    // Get all stats in parallel
    const [verified, pending, failed, fraudAlerts, todayRevenue, activeEmployees, activeBranches] = 
      await Promise.all([
        // Total verified payments (all time)
        this.prisma.payment.count({
          where: { organizationId, status: 'VERIFIED' },
        }),
        // Total pending payments (all time)
        this.prisma.payment.count({
          where: { organizationId, status: 'PENDING' },
        }),
        // Total failed/rejected payments (all time)
        this.prisma.payment.count({
          where: {
            organizationId,
            status: { in: ['FAILED', 'REJECTED'] },
          },
        }),
        // Fraud alerts (high risk score)
        this.prisma.payment.count({
          where: {
            organizationId,
            riskScore: { gte: 70 },
            createdAt: { gte: today },
          },
        }),
        // Today's revenue (sum of verified payments today)
        this.prisma.payment.aggregate({
          where: {
            organizationId,
            status: 'VERIFIED',
            createdAt: { gte: today },
          },
          _sum: { amount: true },
        }),
        // Active employees
        this.prisma.userBusinessAssignment.count({
          where: {
            organizationId,
            status: 'active',
          },
        }),
        // Active branches
        this.prisma.branch.count({
          where: { organizationId },
        }),
      ]);

    // Today's transactions
    const todayTransactions = await this.prisma.payment.count({
      where: {
        organizationId,
        createdAt: { gte: today },
      },
    });

    return {
      totalVerified: verified,
      totalPending: pending,
      totalFailed: failed,
      fraudAlerts,
      todayRevenue: Number(todayRevenue._sum.amount || 0),
      todayTransactions,
      activeEmployees,
      activeBranches,
    };
  }

  /**
   * Get recent activity logs.
   */
  async getRecentActivity(organizationId: string, limit = 10) {
    return this.prisma.activityLog.findMany({
      where: { organizationId },
      include: { user: true },
      orderBy: { createdAt: 'desc' },
      take: limit,
    });
  }

  /**
   * Get recent payments.
   */
  async getRecentPayments(organizationId: string, limit = 10) {
    return this.prisma.payment.findMany({
      where: { organizationId },
      include: { user: true, verificationLogs: true },
      orderBy: { createdAt: 'desc' },
      take: limit,
    });
  }

  /**
   * Get revenue trend for the last N days.
   */
  async getRevenueTrend(organizationId: string, days = 7) {
    const startDate = new Date();
    startDate.setDate(startDate.getDate() - days);
    startDate.setHours(0, 0, 0, 0);

    const payments = await this.prisma.payment.findMany({
      where: {
        organizationId,
        status: 'VERIFIED',
        createdAt: { gte: startDate },
      },
      select: { amount: true, createdAt: true },
    });

    // Group by date
    const grouped: Record<string, number> = {};
    payments.forEach((p) => {
      const date = p.createdAt.toISOString().split('T')[0];
      grouped[date] = (grouped[date] || 0) + Number(p.amount);
    });

    return Object.entries(grouped).map(([date, value]) => ({
      date,
      value,
    }));
  }

  /**
   * Get verification trend for the last N days.
   */
  async getVerificationTrend(organizationId: string, days = 7) {
    const startDate = new Date();
    startDate.setDate(startDate.getDate() - days);
    startDate.setHours(0, 0, 0, 0);

    const payments = await this.prisma.payment.findMany({
      where: {
        organizationId,
        createdAt: { gte: startDate },
      },
      select: { status: true, createdAt: true },
    });

    // Group by date and status
    const grouped: Record<string, Record<string, number>> = {};
    payments.forEach((p) => {
      const date = p.createdAt.toISOString().split('T')[0];
      if (!grouped[date]) {
        grouped[date] = { verified: 0, rejected: 0, failed: 0, pending: 0 };
      }

      if (p.status === 'VERIFIED') grouped[date].verified++;
      else if (p.status === 'REJECTED') grouped[date].rejected++;
      else if (p.status === 'FAILED') grouped[date].failed++;
      else if (p.status === 'PENDING') grouped[date].pending++;
    });

    return Object.entries(grouped).map(([date, data]) => ({
      date,
      ...data,
    }));
  }

  /**
   * Get payment provider statistics.
   */
  async getProviderStats(organizationId: string) {
    const logs = await this.prisma.verificationLog.findMany({
      where: { organizationId },
      select: { matchedProvider: true },
    });

    const grouped: Record<string, number> = {};
    logs.forEach((log) => {
      if (log.matchedProvider) {
        grouped[log.matchedProvider] = (grouped[log.matchedProvider] || 0) + 1;
      }
    });

    return Object.entries(grouped).map(([provider, count]) => ({
      provider,
      count,
    }));
  }

  /**
   * Get branch performance metrics.
   */
  async getBranchPerformance(organizationId: string) {
    const branches = await this.prisma.branch.findMany({
      where: { organizationId },
      include: {
        _count: {
          select: { userAssignments: true },
        },
      },
    });

    // Get stats for each branch
    const stats = await Promise.all(
      branches.map(async (branch) => {
        const [verified, total, revenue] = await Promise.all([
          this.prisma.payment.count({
            where: {
              organization: { branches: { some: { id: branch.id } } },
              status: 'VERIFIED',
            },
          }),
          this.prisma.payment.count({
            where: {
              organization: { branches: { some: { id: branch.id } } },
            },
          }),
          this.prisma.payment.aggregate({
            where: {
              organization: { branches: { some: { id: branch.id } } },
              status: 'VERIFIED',
            },
            _sum: { amount: true },
          }),
        ]);

        return {
          branchId: branch.id,
          branchName: branch.name,
          employees: branch._count.userAssignments,
          verificationRate: total > 0 ? (verified / total) * 100 : 0,
          revenue: Number(revenue._sum.amount || 0),
        };
      }),
    );

    return stats;
  }
}
