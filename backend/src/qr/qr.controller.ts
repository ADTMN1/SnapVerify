import { Controller, Get, Param, Query, Req, UseGuards } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { Role } from '@prisma/client';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { BranchGuard } from '../auth/guards/branch.guard';
import { Permissions } from '../auth/decorators/permissions.decorator';
import { Permission } from '../auth/permissions';
import { resolveThrottlingConfig } from '../config/throttling.config';
import { QrService } from './qr.service';
import { ListQrQueryDto } from './dto/list-qr-query.dto';

const throttling = resolveThrottlingConfig();

/**
 * QR endpoints for payment accounts.
 *
 * All routes require a valid JWT and the VIEW_QR_CODE permission (granted to
 * every role including CASHIER/WAITER). Organization isolation and branch
 * scoping are enforced inside QrService from the token, never from query
 * parameters. Resolve is rate-limited separately because it is the endpoint
 * a scanner calls repeatedly.
 */
@Controller('qr')
@UseGuards(JwtAuthGuard, RolesGuard, BranchGuard)
export class QrController {
  constructor(private readonly qrService: QrService) {}

  /**
   * GET /qr
   * Lists the QR codes of every payment account in the caller's business,
   * optionally filtered by branch, provider, active state or free text.
   */
  @Get()
  @Permissions(Permission.VIEW_QR_CODE)
  list(@Req() req: any, @Query() query: ListQrQueryDto) {
    return this.qrService.listForBusiness(this.context(req), query, req);
  }

  /**
   * GET /qr/accounts/:accountId
   * Returns QR information for one account (used by the account screens and
   * to display QR codes for accounts created before this feature existed).
   */
  @Get('accounts/:accountId')
  @Permissions(Permission.VIEW_QR_CODE)
  accountQr(@Param('accountId') accountId: string, @Req() req: any) {
    return this.qrService.getAccountQr(this.context(req), accountId, req);
  }

  /**
   * GET /qr/resolve/:publicId
   * Resolves a scanned QR identifier for the caller's organization.
   */
  @Get('resolve/:publicId')
  @Throttle({
    default: { ttl: throttling.ttlMs, limit: throttling.qrResolveLimit },
  })
  @Permissions(Permission.VIEW_QR_CODE)
  resolve(@Param('publicId') publicId: string, @Req() req: any) {
    return this.qrService.resolve(publicId, this.context(req), req);
  }

  private context(req: any) {
    return {
      organizationId: req.user.organizationId as string,
      role: req.user.role as Role,
      branchId: (req.user.branchId ?? null) as string | null,
      userId: req.user.sub as string | undefined,
      ipAddress: typeof req.ip === 'string' ? req.ip : undefined,
    };
  }
}
