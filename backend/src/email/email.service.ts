import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as nodemailer from 'nodemailer';

@Injectable()
export class EmailService {
  private readonly logger = new Logger(EmailService.name);
  private transporter: nodemailer.Transporter | null = null;
  private brevoApiKey: string | null = null;
  private from: string;

  constructor(private configService: ConfigService) {
    this.from =
      this.configService.get<string>('EMAIL_FROM') ??
      'SnapVerify <no-reply@snapverify.app>';

    this.brevoApiKey =
      this.configService.get<string>('BREVO_API_KEY') || null;

    const host = this.configService.get<string>('SMTP_HOST');
    const port = Number(this.configService.get<string>('SMTP_PORT') ?? 587);

    if (this.brevoApiKey) {
      this.logger.log('Brevo API provider enabled (BREVO_API_KEY set)');
      return;
    }

    if (!host) {
      this.logger.warn(
        'Neither BREVO_API_KEY nor SMTP_HOST configured — emails will be logged to console only (dev mode)',
      );
      return;
    }

    const user = this.configService.get<string>('SMTP_USER');
    const pass = this.configService.get<string>('SMTP_PASS');

    this.transporter = nodemailer.createTransport({
      host,
      port,
      secure: port === 465,
      auth: user && pass ? { user, pass } : undefined,
    });
  }

  private async sendViaBrevo(
    to: string,
    subject: string,
    text: string,
    html?: string,
  ): Promise<void> {
    const fromMatch = this.from.match(/^(.*?)(?:\s*<([^>]+)>)?$/);
    const senderName = fromMatch?.[1]?.trim() || 'SnapVerify';
    const senderEmail = fromMatch?.[2] ?? this.from;

    const response = await fetch('https://api.brevo.com/v3/smtp/email', {
      method: 'POST',
      headers: {
        'api-key': this.brevoApiKey!,
        'content-type': 'application/json',
        accept: 'application/json',
      },
      body: JSON.stringify({
        sender: { name: senderName, email: senderEmail },
        to: [{ email: to }],
        subject,
        textContent: text,
        ...(html ? { htmlContent: html } : {}),
      }),
    });

    if (!response.ok) {
      const body = await response.text();
      throw new Error(`Brevo API ${response.status}: ${body}`);
    }
  }

  async sendMail(
    to: string,
    subject: string,
    text: string,
    html?: string,
  ): Promise<void> {
    if (this.brevoApiKey) {
      try {
        await this.sendViaBrevo(to, subject, text, html);
        this.logger.log(`Email sent to ${to}: ${subject}`);
      } catch (error) {
        this.logger.error(`Failed to send email to ${to}: ${error}`);
        throw error;
      }
      return;
    }

    if (!this.transporter) {
      this.logger.log(`[DEV ONLY] Email to ${to}: ${subject}\n${text}`);
      return;
    }

    try {
      await this.transporter.sendMail({
        from: this.from,
        to,
        subject,
        text,
        html,
      });
      this.logger.log(`Email sent to ${to}: ${subject}`);
    } catch (error) {
      this.logger.error(`Failed to send email to ${to}: ${error}`);
      throw error;
    }
  }

  async sendOtpEmail(email: string, code: string, purpose: string) {
    const subjectMap: Record<string, string> = {
      register: 'Verify your email — SnapVerify',
      staff_activation: 'Verify your email — SnapVerify staff registration',
      password_reset: 'Reset your password — SnapVerify',
    };

    const actionMap: Record<string, string> = {
      register: 'finish creating your business account',
      staff_activation: 'complete your staff registration',
      password_reset: 'reset your password',
    };

    const subject = subjectMap[purpose] ?? 'Your SnapVerify verification code';
    const action = actionMap[purpose] ?? 'continue';

    const text =
      `Your SnapVerify verification code is ${code}\n\n` +
      `This code expires in 10 minutes and can be used once. ` +
      `Use it to ${action}. If you did not request this, ignore this email.`;

    const html =
      `<div style="font-family:sans-serif;max-width:480px;margin:auto">` +
      `<h2 style="color:#22c55e">SnapVerify</h2>` +
      `<p>Your verification code is:</p>` +
      `<p style="font-size:32px;font-weight:bold;letter-spacing:6px">${code}</p>` +
      `<p>This code expires in <strong>10 minutes</strong> and can be used once.</p>` +
      `<p>If you did not request this, you can safely ignore this email.</p>` +
      `</div>`;

    await this.sendMail(email, subject, text, html);
  }

  async sendStaffInvitationEmail(
    email: string,
    role: string,
    organizationName?: string,
    invitationToken?: string,
  ) {
    const joinLink = invitationToken
      ? `${this.configService.get<string>('APP_URL') ?? ''}/staff/join?token=${invitationToken}`
      : undefined;

    const text =
      `You have been invited to join ${organizationName ?? 'a business'} on SnapVerify as ${role}.` +
      (joinLink ? `\n\nActivate your account: ${joinLink}` : '') +
      `\n\nOpen the SnapVerify app and use "Activate Invitation" to complete registration.`;

    await this.sendMail(
      email,
      `You're invited to join ${organizationName ?? 'a business'} on SnapVerify`,
      text,
    );
  }
}
