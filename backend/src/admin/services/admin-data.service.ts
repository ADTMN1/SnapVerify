import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class AdminDataService {
  private readonly logger = new Logger(AdminDataService.name);

  constructor(private prisma: PrismaService) {}

  private async getOrgId(userId: string): Promise<string> {
    const assignment = await this.prisma.userBusinessAssignment.findFirst({
      where: { userId, role: 'OWNER' },
    });
    if (!assignment) {
      // fallback to any assignment
      const any = await this.prisma.userBusinessAssignment.findFirst({ where: { userId } });
      if (!any) throw new Error('No organization found for this user');
      return any.organizationId;
    }
    return assignment.organizationId;
  }

  async getOrganization(userId: string) {
    const orgId = await this.getOrgId(userId);
    return this.prisma.organization.findUnique({
      where: { id: orgId },
      include: {
        subscriptions: { orderBy: { createdAt: 'desc' }, take: 1 },
        _count: { select: { branches: true, userAssignments: true, payments: true, paymentAccounts: true } },
      },
    });
  }

  async getPayments(userId: string, params: {
    page?: number; limit?: number; status?: string; search?: string;
  }) {
    const orgId = await this.getOrgId(userId);
    const page = params.page ?? 1;
    const limit = Math.min(params.limit ?? 20, 100);
    const skip = (page - 1) * limit;

    const where: any = { organizationId: orgId };
    if (params.status) where.status = params.status;
    if (params.search) {
      where.OR = [
        { transactionId: { contains: params.search, mode: 'insensitive' } },
        { senderName: { contains: params.search, mode: 'insensitive' } },
      ];
    }

    const [data, total] = await Promise.all([
      this.prisma.payment.findMany({
        where, skip, take: limit,
        include: { user: { select: { id: true, fullName: true, phone: true } }, verificationLogs: true },
        orderBy: { createdAt: 'desc' },
      }),
      this.prisma.payment.count({ where }),
    ]);

    return { data, total, page, limit, pages: Math.ceil(total / limit) };
  }

  async getStaff(userId: string) {
    const orgId = await this.getOrgId(userId);
    return this.prisma.userBusinessAssignment.findMany({
      where: { organizationId: orgId },
      include: {
        user: { select: { id: true, fullName: true, phone: true, email: true, status: true, createdAt: true, updatedAt: true } },
        branch: { select: { id: true, name: true } },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  async getBranches(userId: string) {
    const orgId = await this.getOrgId(userId);
    return this.prisma.branch.findMany({
      where: { organizationId: orgId },
      include: {
        _count: { select: { userAssignments: true, paymentAccounts: true } },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  async getPaymentAccounts(userId: string) {
    const orgId = await this.getOrgId(userId);
    return this.prisma.paymentAccount.findMany({
      where: { organizationId: orgId },
      include: { branch: { select: { id: true, name: true } } },
      orderBy: { createdAt: 'desc' },
    });
  }

  async getAuditLogs(userId: string, params: { page?: number; limit?: number; action?: string; search?: string }) {
    const orgId = await this.getOrgId(userId);
    const page = params.page ?? 1;
    const limit = Math.min(params.limit ?? 50, 200);
    const skip = (page - 1) * limit;

    const where: any = { organizationId: orgId };
    if (params.action) where.action = params.action;
    if (params.search) {
      where.OR = [
        { action: { contains: params.search, mode: 'insensitive' } },
        { user: { fullName: { contains: params.search, mode: 'insensitive' } } },
        { ipAddress: { contains: params.search } },
      ];
    }

    const [data, total] = await Promise.all([
      this.prisma.activityLog.findMany({
        where, skip, take: limit,
        include: { user: { select: { id: true, fullName: true, phone: true } } },
        orderBy: { createdAt: 'desc' },
      }),
      this.prisma.activityLog.count({ where }),
    ]);

    return { data, total, page, limit, pages: Math.ceil(total / limit) };
  }

  async getDevices(userId: string) {
    const orgId = await this.getOrgId(userId);
    return this.prisma.device.findMany({
      where: { userAssignment: { organizationId: orgId } },
      include: {
        userAssignment: {
          include: {
            user: { select: { id: true, fullName: true, phone: true } },
            branch: { select: { id: true, name: true } },
          },
        },
      },
      orderBy: { lastLoginAt: 'desc' },
    });
  }

  async getLoginHistory(userId: string, params: { page?: number; limit?: number }) {
    const orgId = await this.getOrgId(userId);
    const page = params.page ?? 1;
    const limit = Math.min(params.limit ?? 50, 200);
    const skip = (page - 1) * limit;

    const where = { organizationId: orgId, action: { in: ['LOGIN', 'LOGOUT', 'ADMIN_LOGIN', 'ADMIN_LOGOUT', 'LOGIN_FAILED'] } };

    const [data, total] = await Promise.all([
      this.prisma.activityLog.findMany({
        where, skip, take: limit,
        include: { user: { select: { id: true, fullName: true, phone: true } } },
        orderBy: { createdAt: 'desc' },
      }),
      this.prisma.activityLog.count({ where }),
    ]);

    return { data, total, page, limit, pages: Math.ceil(total / limit) };
  }

  async getSubscription(userId: string) {
    const orgId = await this.getOrgId(userId);
    return this.prisma.subscription.findFirst({
      where: { organizationId: orgId },
      orderBy: { createdAt: 'desc' },
    });
  }

  async getFraudPayments(userId: string, params: { page?: number; limit?: number; minRisk?: number }) {
    const orgId = await this.getOrgId(userId);
    const page = params.page ?? 1;
    const limit = Math.min(params.limit ?? 20, 100);
    const skip = (page - 1) * limit;
    const minRisk = params.minRisk ?? 60;

    const where = { organizationId: orgId, riskScore: { gte: minRisk } };

    const [data, total] = await Promise.all([
      this.prisma.payment.findMany({
        where, skip, take: limit,
        include: { user: { select: { id: true, fullName: true, phone: true } }, verificationLogs: true },
        orderBy: [{ riskScore: 'desc' }, { createdAt: 'desc' }],
      }),
      this.prisma.payment.count({ where }),
    ]);

    return { data, total, page, limit, pages: Math.ceil(total / limit) };
  }

  async blockDevice(userId: string, deviceId: string) {
    const orgId = await this.getOrgId(userId);
    // Verify device belongs to org
    const device = await this.prisma.device.findFirst({
      where: { id: deviceId, userAssignment: { organizationId: orgId } },
    });
    if (!device) throw new Error('Device not found');
    return this.prisma.device.update({ where: { id: deviceId }, data: { isActive: false } });
  }

  async removeDevice(userId: string, deviceId: string) {
    const orgId = await this.getOrgId(userId);
    const device = await this.prisma.device.findFirst({
      where: { id: deviceId, userAssignment: { organizationId: orgId } },
    });
    if (!device) throw new Error('Device not found');
    return this.prisma.device.delete({ where: { id: deviceId } });
  }
}
