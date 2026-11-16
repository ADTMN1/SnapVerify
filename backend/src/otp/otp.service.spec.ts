import { Test } from '@nestjs/testing';
import { BadRequestException } from '@nestjs/common';
import { OtpService, OTP_PURPOSES } from './otp.service';
import { PrismaService } from '../prisma/prisma.service';
import { EmailService } from '../email/email.service';

describe('OtpService (email)', () => {
  let service: OtpService;
  let prisma: {
    emailOtp: {
      findFirst: jest.Mock;
      count: jest.Mock;
      deleteMany: jest.Mock;
      create: jest.Mock;
      update: jest.Mock;
      updateMany: jest.Mock;
    };
  };
  let emailService: { sendOtpEmail: jest.Mock };

  const EMAIL = 'owner@example.com';

  beforeEach(async () => {
    prisma = {
      emailOtp: {
        findFirst: jest.fn(),
        count: jest.fn(),
        deleteMany: jest.fn(),
        create: jest.fn(),
        update: jest.fn(),
        updateMany: jest.fn(),
      },
    };
    emailService = { sendOtpEmail: jest.fn() };

    const moduleRef = await Test.createTestingModule({
      providers: [
        OtpService,
        { provide: PrismaService, useValue: prisma },
        { provide: EmailService, useValue: emailService },
      ],
    }).compile();

    service = moduleRef.get(OtpService);
  });

  describe('generateOtp', () => {
    it('stores a SHA-256 hash (never plaintext) and emails the code', async () => {
      prisma.emailOtp.findFirst.mockResolvedValue(null);
      prisma.emailOtp.count.mockResolvedValue(0);
      prisma.emailOtp.deleteMany.mockResolvedValue({ count: 0 });
      prisma.emailOtp.create.mockResolvedValue({});

      await service.generateOtp(EMAIL, OTP_PURPOSES.REGISTER);

      const created = prisma.emailOtp.create.mock.calls[0][0].data;
      expect(created.email).toBe(EMAIL.toLowerCase());
      expect(created.purpose).toBe('register');
      expect(created.otpHash).toMatch(/^[a-f0-9]{64}$/);
      expect(created.code).toBeUndefined();
      expect(created.expiresAt.getTime()).toBeGreaterThan(Date.now() + 5 * 60 * 1000);
      expect(emailService.sendOtpEmail).toHaveBeenCalledWith(
        EMAIL.toLowerCase(),
        expect.stringMatching(/^\d{6}$/),
        'register',
      );
      // Email the code, never the hash
      const emailed = emailService.sendOtpEmail.mock.calls[0][1];
      expect(emailed).not.toEqual(created.otpHash);
    });

    it('rejects resend within the 60s cooldown', async () => {
      prisma.emailOtp.findFirst.mockResolvedValue({ id: 'recent' });

      await expect(
        service.generateOtp(EMAIL, OTP_PURPOSES.REGISTER),
      ).rejects.toThrow(BadRequestException);
      expect(prisma.emailOtp.create).not.toHaveBeenCalled();
    });

    it('rejects more than 3 sends per 10-minute window', async () => {
      prisma.emailOtp.findFirst.mockResolvedValue(null);
      prisma.emailOtp.count.mockResolvedValue(3);

      await expect(
        service.generateOtp(EMAIL, OTP_PURPOSES.REGISTER),
      ).rejects.toThrow('Too many verification codes requested');
      expect(prisma.emailOtp.create).not.toHaveBeenCalled();
    });

    it('invalidates older unconsumed codes (single active code)', async () => {
      prisma.emailOtp.findFirst.mockResolvedValue(null);
      prisma.emailOtp.count.mockResolvedValue(0);
      prisma.emailOtp.deleteMany.mockResolvedValue({ count: 1 });
      prisma.emailOtp.create.mockResolvedValue({});

      await service.generateOtp(EMAIL, OTP_PURPOSES.PASSWORD_RESET);

      expect(prisma.emailOtp.deleteMany).toHaveBeenCalledWith({
        where: { email: EMAIL.toLowerCase(), purpose: 'password_reset', consumedAt: null },
      });
    });
  });

  describe('verifyOtp', () => {
    const makeOtp = (over = {}) => ({
      id: 'otp-1',
      email: EMAIL,
      purpose: 'register',
      otpHash: require('crypto').createHash('sha256').update('123456').digest('hex'),
      attempts: 0,
      expiresAt: new Date(Date.now() + 60_000),
      consumedAt: null,
      ...over,
    });

    it('accepts a valid code and consumes it exactly once', async () => {
      prisma.emailOtp.findFirst.mockResolvedValue(makeOtp());
      prisma.emailOtp.updateMany.mockResolvedValue({ count: 1 });

      await service.verifyOtp(EMAIL, '123456', OTP_PURPOSES.REGISTER);

      expect(prisma.emailOtp.updateMany).toHaveBeenCalledWith({
        where: { id: 'otp-1', consumedAt: null },
        data: { consumedAt: expect.any(Date) },
      });
    });

    it('rejects a used code (single-use enforcement)', async () => {
      prisma.emailOtp.findFirst.mockResolvedValue(makeOtp());
      prisma.emailOtp.updateMany.mockResolvedValue({ count: 0 });

      await expect(
        service.verifyOtp(EMAIL, '123456', OTP_PURPOSES.REGISTER),
      ).rejects.toThrow('already used');
    });

    it('rejects expired codes', async () => {
      prisma.emailOtp.findFirst.mockResolvedValue(null);

      await expect(
        service.verifyOtp(EMAIL, '123456', OTP_PURPOSES.REGISTER),
      ).rejects.toThrow('expired or not found');
    });

    it('increments attempts on wrong code and rejects', async () => {
      prisma.emailOtp.findFirst.mockResolvedValue(makeOtp());
      prisma.emailOtp.update.mockResolvedValue({});

      await expect(
        service.verifyOtp(EMAIL, '000000', OTP_PURPOSES.REGISTER),
      ).rejects.toThrow('Incorrect verification code');
      expect(prisma.emailOtp.update).toHaveBeenCalledWith({
        where: { id: 'otp-1' },
        data: { attempts: { increment: 1 } },
      });
    });

    it('blocks verification after 5 incorrect attempts', async () => {
      prisma.emailOtp.findFirst.mockResolvedValue(makeOtp({ attempts: 5 }));

      await expect(
        service.verifyOtp(EMAIL, '123456', OTP_PURPOSES.REGISTER),
      ).rejects.toThrow('Too many incorrect attempts');
    });

    it('normalizes email casing before lookup', async () => {
      prisma.emailOtp.findFirst.mockResolvedValue(null);

      await expect(
        service.verifyOtp('  Owner@Example.COM ', '123456', OTP_PURPOSES.REGISTER),
      ).rejects.toThrow(BadRequestException);
      expect(prisma.emailOtp.findFirst).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({ email: 'owner@example.com' }),
        }),
      );
    });
  });
});
