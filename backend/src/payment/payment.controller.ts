import {
  Controller,
  Post,
  Body,
  Req,
  UseGuards,
  UseInterceptors,
  UploadedFile,
  BadRequestException,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { Role } from '@prisma/client';
import { PaymentService } from './payment.service';
import { VerifyReferenceDto } from './dto/verify-reference.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';

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
  @Roles(Role.OWNER, Role.MANAGER, Role.CASHIER, Role.WAITER)
  async verifyByReference(@Body() dto: VerifyReferenceDto, @Req() req: any) {
    const { sub: userId, organizationId } = req.user;
    return this.paymentService.verifyByReference(
      dto.referenceNumber,
      organizationId,
      userId,
      dto.amount,
      dto.provider,
      dto.suffix,
    );
  }

  /**
   * POST /payments/verify-image
   * Any authenticated staff member can verify a payment by image (OCR).
   */
  @Post('verify-image')
  @Roles(Role.OWNER, Role.MANAGER, Role.CASHIER, Role.WAITER)
  @UseInterceptors(
    FileInterceptor('image', {
      limits: { fileSize: 10 * 1024 * 1024 }, // 10 MB
      fileFilter: (_req, file, cb) => {
        if (!file.mimetype.startsWith('image/')) {
          cb(new BadRequestException('Only image files are accepted'), false);
        } else {
          cb(null, true);
        }
      },
    }),
  )
  async verifyByImage(
    @UploadedFile() file: Express.Multer.File,
    @Req() req: any,
  ) {
    if (!file) throw new BadRequestException('Image file is required');
    const { sub: userId, organizationId } = req.user;
    return this.paymentService.verifyByImage(
      file.buffer,
      file.mimetype,
      organizationId,
      userId,
    );
  }
}
