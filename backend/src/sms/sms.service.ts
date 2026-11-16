import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { HttpService } from '@nestjs/axios';
import { firstValueFrom } from 'rxjs';

@Injectable()
export class SmsService {
  private readonly logger = new Logger(SmsService.name);

  constructor(
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

  private async sendAfroMessageSms(phone: string, text: string): Promise<void> {
    const apiToken = this.configService.get<string>('AFROMESSAGE_API_TOKEN');
    const baseUrl =
      this.configService.get<string>('AFROMESSAGE_BASE_URL') ||
      'https://api.afromessage.com';

    if (!apiToken || apiToken === 'your-afromessage-api-token') {
      this.logger.warn(
        'AFROMESSAGE_API_TOKEN not set or is placeholder, skipping SMS send',
      );
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
    }
  }

  private async sendBrevoSms(phone: string, text: string): Promise<void> {
    const apiKey = this.configService.get<string>('BREVO_API_KEY');
    const sender =
      this.configService.get<string>('BREVO_SMS_SENDER') || 'SnapVerify';

    if (!apiKey) {
      this.logger.warn('BREVO_API_KEY not set, skipping Brevo SMS send');
      return;
    }

    this.logger.log(`Attempting to send SMS via Brevo to ${phone}`);

    try {
      const response = await firstValueFrom(
        this.httpService.post(
          'https://api.brevo.com/v3/transactionalSMS/sms',
          { sender, recipient: phone, content: text, type: 'transactional' },
          {
            headers: {
              'api-key': apiKey,
              'Content-Type': 'application/json',
              Accept: 'application/json',
            },
          },
        ),
      );
      this.logger.log(
        `SMS sent successfully to ${phone}, response: ${JSON.stringify(response.data)}`,
      );
    } catch (error) {
      this.logger.error(
        `Failed to send SMS via Brevo to ${phone}:`,
        error.response?.data || error.message,
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
    }
  }

  private async sendSms(phone: string, text: string): Promise<void> {
    const hasAfroMessage = !!this.configService.get<string>(
      'AFROMESSAGE_API_TOKEN',
    );
    if (hasAfroMessage) {
      await this.sendAfroMessageSms(phone, text);
    } else if (this.configService.get<string>('BREVO_API_KEY')) {
      await this.sendBrevoSms(phone, text);
    } else {
      await this.sendSmsEthiopia(phone, text);
    }
  }

  async sendInvitationSms(
    phone: string,
    role: string,
    organizationName?: string,
  ): Promise<void> {
    const formattedPhone = this.formatPhoneNumber(phone);
    const message = organizationName
      ? `You have been invited to join ${organizationName} as ${role} on SnapVerify. Please activate your invitation to complete registration.`
      : `You have been invited to join as ${role} on SnapVerify. Please activate your invitation to complete registration.`;

    await this.sendSms(formattedPhone, message);
  }
}
