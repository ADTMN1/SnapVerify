import { Controller, Get, Query, Req, UseGuards } from '@nestjs/common';
import { Role } from '@prisma/client';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { ReportsService } from './reports.service';

/**
 * Reporting endpoints.
 *
 * All routes require a valid JWT and an authorized role. Data is always scoped
 * to the caller's organization (and, for cashiers/waiters, to their own
 * activity) inside ReportsService.
 */
@Controller('reports')
@UseGuards(JwtAuthGuard, RolesGuard)
export class ReportsController {
  constructor(private reportsService: ReportsService) {}

  /**
   * GET /reports/summary?from=YYYY-MM-DD&to=YYYY-MM-DD
   * Real aggregates for the caller's organization over the requested range.
   */
  @Get('summary')
  @Roles(Role.OWNER, Role.MANAGER, Role.CASHIER, Role.WAITER)
  async summary(
    @Req() req: any,
    @Query('from') from?: string,
    @Query('to') to?: string,
  ) {
    const { sub: userId, organizationId, role } = req.user;
    return this.reportsService.getSummary({
      organizationId,
      userId,
      role,
      from,
      to,
    });
  }
}