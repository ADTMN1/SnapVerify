import {
  Controller,
  Post,
  Get,
  Body,
  Req,
  UseGuards,
  UseInterceptors,
  UploadedFile,
  BadRequestException,
  ForbiddenException,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { Throttle } from '@nestjs/throttler';
import { Role } from '@prisma/client';
import { PaymentService } from './payment.service';
import { VerifyReferenceDto } from './dto/verify-reference.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { SubscriptionGuard } from '../auth/guards/subscription.guard';
import { resolveThrottlingConfig } from '../config/throttling.config';

// Stage 1: upstream verification calls are expensive (OCR + per-account
// verification against the external provider), so the payment endpoints are
// throttled more strictly than the application default. Limits are shared
// per organization (all staff of one merchant draw from the same bucket).
const throttling = resolveThrottlingConfig();

/**
 * All payment routes require:
 *  1. A valid JWT (JwtAuthGuard)
 *  2. The caller to be a CASHIER, WAITER, MANAGER, or OWNER (RolesGuard)
 *
 * Add @Roles(Role.OWNER, Role.MANAGER) on individual routes to restrict them
 * further (e.g. viewing all payments across the org).
 */
@Controller('payments')
@UseGuards(JwtAuthGuard, RolesGuard)
export class PaymentController {
  constructor(private paymentService: PaymentService) {}

  /**
   * POST /payments/verify
   * Any authenticated staff member can verify a payment by reference number.
   */
  @Post('verify')
  @UseGuards(SubscriptionGuard)
  @Throttle({
    default: { ttl: throttling.ttlMs, limit: throttling.paymentVerifyLimit },
  })
  @Roles(Role.OWNER, Role.MANAGER, Role.CASHIER, Role.WAITER)
  async verifyByReference(@Body() dto: VerifyReferenceDto, @Req() req: any) {
    const { sub: userId, organizationId, role, branchId } = req.user;
    // A missing branch ID for non-OWNER staff is never treated as
    // unrestricted access to every receiving account in the organization.
    if (role !== Role.OWNER && !branchId) {
      throw new ForbiddenException(
        'You must be assigned to a branch to verify payments.',
      );
    }
    const userBranchId = role === 'OWNER' ? undefined : branchId;
    return this.paymentService.verifyByReference(
      dto.referenceNumber,
      organizationId,
      userId,
      dto.amount,
      dto.provider,
      dto.suffix,
      userBranchId,
    );
  }

  /**
   * POST /payments/verify-image
   * Any authenticated staff member can verify a payment by image (OCR).
   */
  @Post('verify-image')
  @UseGuards(SubscriptionGuard)
  @Throttle({
    default: {
      ttl: throttling.ttlMs,
      limit: throttling.paymentVerifyImageLimit,
    },
  })
  @Roles(Role.OWNER, Role.MANAGER, Role.CASHIER, Role.WAITER)
  @UseInterceptors(
    FileInterceptor('image', {
      limits: { fileSize: 10 * 1024 * 1024 }, // 10 MB
      fileFilter: (_req, file, cb) => {
        if (!file.mimetype.startsWith('image/')) {
          throw new BadRequestException('Please upload an image file.');
        } else {
          cb(null, true);
        }
      },
    }),
  )
  async verifyByImage(
    @UploadedFile() file: Express.Multer.File,
    @Body('receiptText') receiptText: string,
    @Req() req: any,
  ) {
    if (!file)
      throw new BadRequestException('Please select an image file to upload.');
    const { sub: userId, organizationId, role, branchId } = req.user;
    // A missing branch ID for non-OWNER staff is never treated as
    // unrestricted access to every receiving account in the organization.
    if (role !== Role.OWNER && !branchId) {
      throw new ForbiddenException(
        'You must be assigned to a branch to verify payments.',
      );
    }
    const userBranchId = role === 'OWNER' ? undefined : branchId;
    return this.paymentService.verifyByImage(
      file.buffer,
      file.mimetype,
      organizationId,
      userId,
      receiptText,
      userBranchId,
    );
  }

  /**
   * GET /payments/history
   * Returns recent verification attempts for the current organization.
   */
  @Get('history')
  @Roles(Role.OWNER, Role.MANAGER, Role.CASHIER, Role.WAITER)
  async getHistory(@Req() req: any) {
    const { sub: userId, organizationId, role } = req.user;
    return this.paymentService.getVerificationHistory(
      organizationId,
      userId,
      role,
    );
  }
}
