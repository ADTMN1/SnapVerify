import 'dotenv/config';
import { ConfigService } from '@nestjs/config';
import { HttpService } from '@nestjs/axios';
import { SmsService } from '../src/sms/sms.service';

async function main() {
  const config = new ConfigService();
  const http = new HttpService();
  const sms = new SmsService(config, http);
  const email = new (require('../src/email/email.service').EmailService)(
    config,
  );

  const to = process.argv[2];
  if (!to) {
    console.error('Usage: npx ts-node scripts/test-brevo.ts <phone-or-email>');
    process.exit(1);
  }

  const isEmail = to.includes('@');
  console.log(`Target: ${to} (${isEmail ? 'email' : 'sms'})`);

  try {
    if (isEmail) {
      await email.sendMail(to, 'SnapVerify test', 'Brevo test email');
    } else {
      await sms.sendInvitationSms(to, 'cashier', 'Test Org');
    }
    console.log('OK — check logs above / your inbox');
  } catch (e) {
    console.error('FAILED:', e);
    process.exit(1);
  }
  process.exit(0);
}

main();
