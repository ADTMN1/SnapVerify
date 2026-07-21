import { Injectable, BadRequestException, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import * as crypto from 'crypto';
import { ConfigService } from '@nestjs/config';
import { HttpService } from '@nestjs/axios';
import { firstValueFrom } from 'rxjs';

@Injectable()
export class OtpService {
  private readonly logger = new Logger(OtpService.name);

  constructor(
    private prisma: PrismaService,
    private configService: ConfigService,
    private httpService: HttpService,
  ) {}

  private formatPhoneNumber(phone: string): string {
    let formatted = phone.replace(/\s+/g, '').replace(/^\+/, '');
    if (formatted.startsWith('09')) {
      formatted = '251' + formatted.slice(1);
    } else if (formatted.startsWith('9')) {
      formatted = '251' + formatted;
    }
    return formatted;
  }

  private hashOtp(otp: string): string {
    return crypto.createHash('sha256').update(otp).digest('hex');
  }

  private async sendSms(phone: string, text: string): Promise<void> {
    const apiKey = this.configService.get<string>('SMSETHIOPIA_API_KEY');
    const baseUrl = 'https://smsethiopia.et/api/sms/send';

    if (!apiKey) {
      this.logger.warn('SMSETHIOPIA_API_KEY not set, skipping SMS send');
      return;
    }

    this.logger.log(`Attempting to send SMS to ${phone} with text: ${text}`);

    try {
      const response = await firstValueFrom(
        this.httpService.post(
          baseUrl,
          { msisdn: phone, text },
          { headers: { KEY: apiKey } },
        ),
      );
      this.logger.log(
        `SMS sent successfully to ${phone}, response: ${JSON.stringify(response.data)}`,
      );
    } catch (error) {
      this.logger.error(
        `Failed to send SMS to ${phone}:`,
        error.response?.data || error.message,
      );
      throw new BadRequestException('Failed to send SMS');
    }
  }

  async generateOtp(phone: string): Promise<string> {
    const formattedPhone = this.formatPhoneNumber(phone);

    const tenMinutesAgo = new Date(Date.now() - 10 * 60 * 1000);
    const recentOtpCount = await this.prisma.otpCode.count({
      where: {
        phone: formattedPhone,
        createdAt: { gte: tenMinutesAgo },
      },
    });

    if (recentOtpCount >= 3) {
      throw new BadRequestException(
        'Too many OTP requests. Please try again later.',
      );
    }

    await this.prisma.otpCode.deleteMany({ where: { phone: formattedPhone } });

    const code = crypto.randomInt(100000, 999999).toString();
    const otpHash = this.hashOtp(code);
    const expiresAt = new Date(Date.now() + 5 * 60 * 1000);

    await this.prisma.otpCode.create({
      data: { phone: formattedPhone, otpHash, expiresAt },
    });

    await this.sendSms(formattedPhone, `Your OTP code is ${code}`);

    this.logger.debug(`[DEV ONLY] OTP for ${formattedPhone}: ${code}`);

    return code;
  }

  async verifyOtp(phone: string, code: string): Promise<boolean> {
    const formattedPhone = this.formatPhoneNumber(phone);

    const otp = await this.prisma.otpCode.findFirst({
      where: {
        phone: formattedPhone,
        isUsed: false,
        expiresAt: { gt: new Date() },
      },
      orderBy: { createdAt: 'desc' },
    });

    if (!otp) {
      throw new BadRequestException('OTP expired or not found');
    }

    if (otp.otpHash !== this.hashOtp(code)) {
      await this.prisma.otpCode.update({
        where: { id: otp.id },
        data: { attempts: { increment: 1 } },
      });
      throw new BadRequestException('Invalid OTP');
    }

    await this.prisma.otpCode.delete({
      where: { id: otp.id },
    });

    return true;
  }

  async sendInvitationSms(phone: string, role: string): Promise<void> {
    const formattedPhone = this.formatPhoneNumber(phone);
    const message = `You have been invited to join as ${role}. Please verify your phone number to complete registration.`;
    
    await this.sendSms(formattedPhone, message);
  }
}
