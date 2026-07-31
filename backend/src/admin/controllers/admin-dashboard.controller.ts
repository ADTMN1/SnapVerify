import {
  Controller,
  Get,
  UseGuards,
  Query,
  Logger,
  HttpCode,
} from '@nestjs/common';
import type { AdminAuthContext } from '../interfaces/admin-jwt-payload.interface';
import { AdminDashboardService } from '../services/admin-dashboard.service';
import { AdminJwtAuthGuard } from '../guards/admin-jwt-auth.guard';
import { AdminRolesGuard } from '../guards/admin-roles.guard';
import { CurrentAdmin } from '../decorators/current-admin.decorator';
import { PrismaService } from '../../prisma/prisma.service';

@Controller('api/admin/dashboard')
@UseGuards(AdminJwtAuthGuard, AdminRolesGuard)
export class AdminDashboardController {
  private readonly logger = new Logger(AdminDashboardController.name);

  constructor(
    private dashboardService: AdminDashboardService,
    private prisma: PrismaService,
  ) {}

  @Get('stats')
  async getStats(@CurrentAdmin() admin: any) {
    // Get the admin's organization
    const assignment = await this.prisma.userBusinessAssignment.findFirst({
      where: { userId: admin.sub, role: 'OWNER' },
    });

    if (!assignment) {
      throw new Error('Admin organization not found');
    }

    const stats = await this.dashboardService.getDashboardStats(assignment.organizationId);
    return stats;
  }

  @Get('activity')
  async getActivity(
    @CurrentAdmin() admin: any,
    @Query('limit') limit?: string,
  ) {
    const assignment = await this.prisma.userBusinessAssignment.findFirst({
      where: { userId: admin.sub, role: 'OWNER' },
    });

    if (!assignment) {
      throw new Error('Admin organization not found');
    }

    const limitNum = parseInt(limit || '10', 10);
    return this.dashboardService.getRecentActivity(
      assignment.organizationId,
      limitNum,
    );
  }

  @Get('payments')
  async getPayments(
    @CurrentAdmin() admin: any,
    @Query('limit') limit?: string,
  ) {
    const assignment = await this.prisma.userBusinessAssignment.findFirst({
      where: { userId: admin.sub, role: 'OWNER' },
    });

    if (!assignment) {
      throw new Error('Admin organization not found');
    }

    const limitNum = parseInt(limit || '10', 10);
    return this.dashboardService.getRecentPayments(
      assignment.organizationId,
      limitNum,
    );
  }

  @Get('revenue-trend')
  async getRevenueTrend(
    @CurrentAdmin() admin: any,
    @Query('days') days?: string,
  ) {
    const assignment = await this.prisma.userBusinessAssignment.findFirst({
      where: { userId: admin.sub, role: 'OWNER' },
    });

    if (!assignment) {
      throw new Error('Admin organization not found');
    }

    const daysNum = parseInt(days || '7', 10);
    return this.dashboardService.getRevenueTrend(
      assignment.organizationId,
      daysNum,
    );
  }

  @Get('verification-trend')
  async getVerificationTrend(
    @CurrentAdmin() admin: any,
    @Query('days') days?: string,
  ) {
    const assignment = await this.prisma.userBusinessAssignment.findFirst({
      where: { userId: admin.sub, role: 'OWNER' },
    });

    if (!assignment) {
      throw new Error('Admin organization not found');
    }

    const daysNum = parseInt(days || '7', 10);
    return this.dashboardService.getVerificationTrend(
      assignment.organizationId,
      daysNum,
    );
  }

  @Get('provider-stats')
  async getProviderStats(@CurrentAdmin() admin: any) {
    const assignment = await this.prisma.userBusinessAssignment.findFirst({
      where: { userId: admin.sub, role: 'OWNER' },
    });

    if (!assignment) {
      throw new Error('Admin organization not found');
    }

    return this.dashboardService.getProviderStats(assignment.organizationId);
  }

  @Get('branch-performance')
  async getBranchPerformance(@CurrentAdmin() admin: any) {
    const assignment = await this.prisma.userBusinessAssignment.findFirst({
      where: { userId: admin.sub, role: 'OWNER' },
    });

    if (!assignment) {
      throw new Error('Admin organization not found');
    }

    return this.dashboardService.getBranchPerformance(assignment.organizationId);
  }
}
