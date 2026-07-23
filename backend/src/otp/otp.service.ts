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

  private async sendAfroMessageSms(phone: string, text: string): Promise<void> {
    const apiToken = this.configService.get<string>('AFROMESSAGE_API_TOKEN');
    const baseUrl = this.configService.get<string>('AFROMESSAGE_BASE_URL') || 'https://api.afromessage.com';

    if (!apiToken || apiToken === 'your-afromessage-api-token') {
      this.logger.warn('AFROMESSAGE_API_TOKEN not set or is placeholder, skipping SMS send');
      return;
    }

    this.logger.log(`Attempting to send SMS via AfroMessage to ${phone}`);

    try {
      const response = await firstValueFrom(
        this.httpService.post(
          `${baseUrl}/api/send`,
          { to: phone, message: text },
          {
            headers: {
              Authorization: `Bearer ${apiToken}`,
              'Content-Type': 'application/json',
            },
          },
        ),
      );
      this.logger.log(
        `SMS sent successfully to ${phone}, response: ${JSON.stringify(response.data)}`,
      );
    } catch (error) {
      this.logger.error(
        `Failed to send SMS via AfroMessage to ${phone}:`,
        error.response?.data || error.message,
      );
      this.logger.warn(
        'Skipping SMS due to failure, OTP is still logged to console',
      );
    }
  }

  private async sendSmsEthiopia(phone: string, text: string): Promise<void> {
    const apiKey = this.configService.get<string>('SMSETHIOPIA_API_KEY');
    const baseUrl = 'https://smsethiopia.et/api/sms/send';

    if (!apiKey) {
      this.logger.warn('SMSETHIOPIA_API_KEY not set, skipping SMS send');
      return;
    }

    this.logger.log(`Attempting to send SMS via SMSEthiopia to ${phone}`);

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
        `Failed to send SMS via SMSEthiopia to ${phone}:`,
        error.response?.data || error.message,
      );
      this.logger.warn(
        'Skipping SMS due to failure, OTP is still logged to console',
      );
    }
  }

  private async sendSms(phone: string, text: string): Promise<void> {
    const hasAfroMessage = !!this.configService.get<string>(
      'AFROMESSAGE_API_TOKEN',
    );
    if (hasAfroMessage) {
      await this.sendAfroMessageSms(phone, text);
    } else {
      await this.sendSmsEthiopia(phone, text);
    }
  }

  async generateOtp(phone: string): Promise<string> {
    const formattedPhone = this.formatPhoneNumber(phone);

    const sixtySecondsAgo = new Date(Date.now() - 60 * 1000);
    const recentOtp = await this.prisma.otpCode.findFirst({
      where: {
        phone: formattedPhone,
        createdAt: { gte: sixtySecondsAgo },
      },
    });

    if (recentOtp) {
      throw new BadRequestException(
        'Please wait 60 seconds before requesting another OTP.',
      );
    }

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

    await this.sendSms(formattedPhone, `Your SnapVerify OTP code is ${code}`);
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

    if (otp.attempts >= 5) {
      throw new BadRequestException(
        'Too many invalid attempts. Please request a new OTP.',
      );
    }

    if (otp.otpHash !== this.hashOtp(code)) {
      await this.prisma.otpCode.update({
        where: { id: otp.id },
        data: { attempts: { increment: 1 } },
      });
      throw new BadRequestException('Invalid OTP');
    }

    await this.prisma.otpCode.delete({ where: { id: otp.id } });
    return true;
  }

  async sendInvitationSms(
    phone: string,
    role: string,
    organizationName?: string,
  ): Promise<void> {
    const formattedPhone = this.formatPhoneNumber(phone);
    const message = organizationName
      ? `You have been invited to join ${organizationName} as ${role} on SnapVerify. Please verify your phone number to complete registration.`
      : `You have been invited to join as ${role} on SnapVerify. Please verify your phone number to complete registration.`;

    await this.sendSms(formattedPhone, message);
  }

  async checkAfroMessageBalance(): Promise<any> {
    const apiToken = this.configService.get<string>('AFROMESSAGE_API_TOKEN');
    const baseUrl =
      this.configService.get<string>('AFROMESSAGE_BASE_URL') ||
      'https://api.afromessage.com';

    if (!apiToken) {
      throw new BadRequestException('AFROMESSAGE_API_TOKEN not configured');
    }

    const response = await firstValueFrom(
      this.httpService.get(`${baseUrl}/api/balance`, {
        headers: { Authorization: `Bearer ${apiToken}` },
      }),
    );
    return response.data;
  }
}
