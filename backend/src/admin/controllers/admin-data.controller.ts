import {
  Controller, Get, Patch, Delete, UseGuards, Query, Param, HttpCode, HttpStatus, Logger,
} from '@nestjs/common';
import { AdminDataService } from '../services/admin-data.service';
import { AdminJwtAuthGuard } from '../guards/admin-jwt-auth.guard';
import { AdminRolesGuard } from '../guards/admin-roles.guard';
import { CurrentAdmin } from '../decorators/current-admin.decorator';

@Controller('api/admin/data')
@UseGuards(AdminJwtAuthGuard, AdminRolesGuard)
export class AdminDataController {
  private readonly logger = new Logger(AdminDataController.name);

  constructor(private dataService: AdminDataService) {}

  @Get('organization')
  getOrganization(@CurrentAdmin() admin: any) {
    return this.dataService.getOrganization(admin.sub);
  }

  @Get('payments')
  getPayments(
    @CurrentAdmin() admin: any,
    @Query('page') page?: string,
    @Query('limit') limit?: string,
    @Query('status') status?: string,
    @Query('search') search?: string,
  ) {
    return this.dataService.getPayments(admin.sub, {
      page: page ? parseInt(page) : undefined,
      limit: limit ? parseInt(limit) : undefined,
      status,
      search,
    });
  }

  @Get('staff')
  getStaff(@CurrentAdmin() admin: any) {
    return this.dataService.getStaff(admin.sub);
  }

  @Get('branches')
  getBranches(@CurrentAdmin() admin: any) {
    return this.dataService.getBranches(admin.sub);
  }

  @Get('payment-accounts')
  getPaymentAccounts(@CurrentAdmin() admin: any) {
    return this.dataService.getPaymentAccounts(admin.sub);
  }

  @Get('audit-logs')
  getAuditLogs(
    @CurrentAdmin() admin: any,
    @Query('page') page?: string,
    @Query('limit') limit?: string,
    @Query('action') action?: string,
    @Query('search') search?: string,
  ) {
    return this.dataService.getAuditLogs(admin.sub, {
      page: page ? parseInt(page) : undefined,
      limit: limit ? parseInt(limit) : undefined,
      action,
      search,
    });
  }

  @Get('devices')
  getDevices(@CurrentAdmin() admin: any) {
    return this.dataService.getDevices(admin.sub);
  }

  @Get('login-history')
  getLoginHistory(
    @CurrentAdmin() admin: any,
    @Query('page') page?: string,
    @Query('limit') limit?: string,
  ) {
    return this.dataService.getLoginHistory(admin.sub, {
      page: page ? parseInt(page) : undefined,
      limit: limit ? parseInt(limit) : undefined,
    });
  }

  @Get('subscription')
  getSubscription(@CurrentAdmin() admin: any) {
    return this.dataService.getSubscription(admin.sub);
  }

  @Get('fraud')
  getFraud(
    @CurrentAdmin() admin: any,
    @Query('page') page?: string,
    @Query('limit') limit?: string,
    @Query('minRisk') minRisk?: string,
  ) {
    return this.dataService.getFraudPayments(admin.sub, {
      page: page ? parseInt(page) : undefined,
      limit: limit ? parseInt(limit) : undefined,
      minRisk: minRisk ? parseInt(minRisk) : undefined,
    });
  }

  @Patch('devices/:id/block')
  @HttpCode(HttpStatus.OK)
  blockDevice(@CurrentAdmin() admin: any, @Param('id') id: string) {
    return this.dataService.blockDevice(admin.sub, id);
  }

  @Delete('devices/:id')
  @HttpCode(HttpStatus.OK)
  removeDevice(@CurrentAdmin() admin: any, @Param('id') id: string) {
    return this.dataService.removeDevice(admin.sub, id);
  }
}
