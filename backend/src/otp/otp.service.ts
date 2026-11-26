import { Injectable, BadRequestException, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { EmailService } from '../email/email.service';
import * as crypto from 'crypto';

export const OTP_PURPOSES = {
  REGISTER: 'register',
  STAFF_ACTIVATION: 'staff_activation',
  PASSWORD_RESET: 'password_reset',
} as const;

export type OtpPurpose = (typeof OTP_PURPOSES)[keyof typeof OTP_PURPOSES];

const OTP_TTL_MS = 10 * 60 * 1000; // 10 minutes
const RESEND_COOLDOWN_MS = 60 * 1000; // 60 seconds between sends
const MAX_SENDS_PER_WINDOW = 3;
const SEND_WINDOW_MS = 10 * 60 * 1000;
const MAX_ATTEMPTS = 5;

function normalizeEmail(email: string): string {
  return email.trim().toLowerCase();
}

@Injectable()
export class OtpService {
  private readonly logger = new Logger(OtpService.name);

  constructor(
    private prisma: PrismaService,
    private emailService: EmailService,
  ) {}

  private hashOtp(otp: string): string {
    // Codes are never stored as plaintext — SHA-256 hex digest.
    return crypto.createHash('sha256').update(otp).digest('hex');
  }

  /**
   * Generate a 6-digit OTP for `email`, store it hashed, and email it.
   * Enforces resend cooldown + per-window send limits.
   */
  async generateOtp(email: string, purpose: OtpPurpose): Promise<void> {
    const normalized = normalizeEmail(email);

    // Resend cooldown: one send per 60s per email+purpose
    const recent = await this.prisma.emailOtp.findFirst({
      where: {
        email: normalized,
        purpose,
        createdAt: { gte: new Date(Date.now() - RESEND_COOLDOWN_MS) },
      },
    });
    if (recent) {
      throw new BadRequestException(
        'Please wait 60 seconds before requesting another code.',
      );
    }

    // Max 3 sends per 10-minute window per email+purpose
    const windowCount = await this.prisma.emailOtp.count({
      where: {
        email: normalized,
        purpose,
        createdAt: { gte: new Date(Date.now() - SEND_WINDOW_MS) },
      },
    });
    if (windowCount >= MAX_SENDS_PER_WINDOW) {
      throw new BadRequestException(
        'Too many verification codes requested. Please try again later.',
      );
    }

    // Single active code per email+purpose: invalidate older unconsumed ones
    await this.prisma.emailOtp.deleteMany({
      where: { email: normalized, purpose, consumedAt: null },
    });

    const code = crypto.randomInt(100000, 999999).toString();

    await this.prisma.emailOtp.create({
      data: {
        email: normalized,
        purpose,
        otpHash: this.hashOtp(code),
        expiresAt: new Date(Date.now() + OTP_TTL_MS),
      },
    });

    await this.emailService.sendOtpEmail(normalized, code, purpose);
    this.logger.debug(`[DEV ONLY] OTP generated for ${normalized} (${purpose})`);
  }

  /**
   * Verify an OTP. Throws BadRequestException on any failure.
   * `consume: false` checks validity without consuming the code (used for
   * multi-step flows where a later step consumes it).
   */
  async verifyOtp(
    email: string,
    code: string,
    purpose: OtpPurpose,
    consume = true,
  ): Promise<void> {
    const normalized = normalizeEmail(email);

    const otp = await this.prisma.emailOtp.findFirst({
      where: {
        email: normalized,
        purpose,
        consumedAt: null,
        expiresAt: { gt: new Date() },
      },
      orderBy: { createdAt: 'desc' },
    });

    if (!otp) {
      throw new BadRequestException(
        'Verification code expired or not found. Please request a new one.',
      );
    }

    if (otp.attempts >= MAX_ATTEMPTS) {
      throw new BadRequestException(
        'Too many incorrect attempts. Please request a new code.',
      );
    }

    if (otp.otpHash !== this.hashOtp(code)) {
      await this.prisma.emailOtp.update({
        where: { id: otp.id },
        data: { attempts: { increment: 1 } },
      });
      throw new BadRequestException('Incorrect verification code');
    }

    if (consume) {
      // Single-use: consume atomically so a code can never verify twice.
      const result = await this.prisma.emailOtp.updateMany({
        where: { id: otp.id, consumedAt: null },
        data: { consumedAt: new Date() },
      });
      if (result.count === 0) {
        throw new BadRequestException(
          'Verification code already used. Please request a new one.',
        );
      }
    }
  }
}
