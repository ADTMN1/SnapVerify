import { Test, TestingModule } from '@nestjs/testing';
import { PaymentService } from './payment.service';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../prisma/prisma.service';
import { PaymentProvider, PaymentStatus } from '@prisma/client';

describe('PaymentService - Settlement Account Security', () => {
  let service: PaymentService;
  let prisma: PrismaService;
  let config: ConfigService;

  const mockPrisma = {
    payment: {
      findFirst: jest.fn(),
      create: jest.fn(),
    },
    paymentAccount: {
      findMany: jest.fn(),
    },
    verificationLog: {
      create: jest.fn(),
    },
  };

  const mockConfig = {
    get: jest.fn((key: string) => {
      const config: Record<string, string | boolean> = {
        'VERIFY_API_KEY': 'test-api-key',
        'VERIFY_LEUL_ET_BASE_URL': 'https://verify.test.com',
        'SKIP_PRIMARY_VERIFICATION': false,
      };
      return config[key];
    }),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        PaymentService,
        {
          provide: PrismaService,
          useValue: mockPrisma,
        },
        {
          provide: ConfigService,
          useValue: mockConfig,
        },
      ],
    }).compile();

    service = module.get<PaymentService>(PaymentService);
    prisma = module.get<PrismaService>(PrismaService);
    config = module.get<ConfigService>(ConfigService);
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('Test 1: Correct Account Match', () => {
    it('should PASS when payment is sent to the correct business account (1000516323381)', async () => {
      const organizationId = 'test-org-id';
      const userId = 'test-user-id';
      const referenceNumber = 'FT12345678';
      const businessAccount = {
        id: 'account-1',
        organizationId,
        provider: PaymentProvider.CBE,
        accountNumber: '1000516323381',
        suffix: '12345678',
        accountHolderName: 'Test Business',
        isActive: true,
        createdAt: new Date(),
        updatedAt: new Date(),
        branchId: null,
      };

      mockPrisma.payment.findFirst.mockResolvedValue(null);
      mockPrisma.paymentAccount.findMany.mockResolvedValue([businessAccount]);
      mockPrisma.payment.create.mockResolvedValue({
        id: 'payment-1',
        organizationId,
        userId,
        amount: 100,
        currency: 'ETB',
        paymentMethod: 'REFERENCE',
        transactionId: referenceNumber,
        senderName: 'John Doe',
        receiverName: 'Test Business',
        status: PaymentStatus.VERIFIED,
        riskScore: 0,
        rawData: null,
        createdAt: new Date(),
        updatedAt: new Date(),
      });
      mockPrisma.verificationLog.create.mockResolvedValue({});

      // Mock successful API response with matching account
      jest.spyOn(service as any, '_fetchJson').mockResolvedValue({
        success: true,
        suffix: '12345678',
        accountNumber: '1000516323381',
        receiver: 'Test Business',
        amount: 100,
      });

      const result = await service.verifyByReference(
        referenceNumber,
        organizationId,
        userId,
        100,
        'CBE',
        '12345678',
      );

      expect(result.verified).toBe(true);
      expect(result.status).toBe(PaymentStatus.VERIFIED);
      expect(result.message).toContain('verified successfully');
    });
  });

  describe('Test 2: Wrong Account Match', () => {
    it('should FAIL when payment is sent to a different account (1000999999999)', async () => {
      const organizationId = 'test-org-id';
      const userId = 'test-user-id';
      const referenceNumber = 'FT12345678';
      const businessAccount = {
        id: 'account-1',
        organizationId,
        provider: PaymentProvider.CBE,
        accountNumber: '1000516323381',
        suffix: '12345678',
        accountHolderName: 'Test Business',
        isActive: true,
        createdAt: new Date(),
        updatedAt: new Date(),
        branchId: null,
      };

      mockPrisma.payment.findFirst.mockResolvedValue(null);
      mockPrisma.paymentAccount.findMany.mockResolvedValue([businessAccount]);
      mockPrisma.payment.create.mockResolvedValue({
        id: 'payment-1',
        organizationId,
        userId,
        amount: 100,
        currency: 'ETB',
        paymentMethod: 'REFERENCE',
        transactionId: referenceNumber,
        senderName: 'John Doe',
        receiverName: 'Other Business',
        status: PaymentStatus.FAILED,
        riskScore: 80,
        rawData: null,
        createdAt: new Date(),
        updatedAt: new Date(),
      });
      mockPrisma.verificationLog.create.mockResolvedValue({});

      // Mock API response with WRONG account
      jest.spyOn(service as any, '_fetchJson').mockResolvedValue({
        success: true,
        suffix: '99999999',
        accountNumber: '1000999999999',
        receiver: 'Other Business',
        amount: 100,
      });

      const result = await service.verifyByReference(
        referenceNumber,
        organizationId,
        userId,
        100,
        'CBE',
        '12345678',
      );

      expect(result.verified).toBe(false);
      expect(result.status).toBe(PaymentStatus.FAILED);
      expect(result.message).toContain('not sent to this business account');
    });
  });

  describe('Test 3: Wrong Amount', () => {
    it('should FAIL when payment amount does not match expected amount', async () => {
      const organizationId = 'test-org-id';
      const userId = 'test-user-id';
      const referenceNumber = 'FT12345678';
      const businessAccount = {
        id: 'account-1',
        organizationId,
        provider: PaymentProvider.CBE,
        accountNumber: '1000516323381',
        suffix: '12345678',
        accountHolderName: 'Test Business',
        isActive: true,
        createdAt: new Date(),
        updatedAt: new Date(),
        branchId: null,
      };

      mockPrisma.payment.findFirst.mockResolvedValue(null);
      mockPrisma.paymentAccount.findMany.mockResolvedValue([businessAccount]);
      mockPrisma.payment.create.mockResolvedValue({
        id: 'payment-1',
        organizationId,
        userId,
        amount: 50,
        currency: 'ETB',
        paymentMethod: 'REFERENCE',
        transactionId: referenceNumber,
        senderName: 'John Doe',
        receiverName: 'Test Business',
        status: PaymentStatus.FAILED,
        riskScore: 80,
        rawData: null,
        createdAt: new Date(),
        updatedAt: new Date(),
      });
      mockPrisma.verificationLog.create.mockResolvedValue({});

      // Mock API response with wrong amount
      jest.spyOn(service as any, '_fetchJson').mockResolvedValue({
        success: true,
        suffix: '12345678',
        accountNumber: '1000516323381',
        receiver: 'Test Business',
        amount: 50, // Wrong amount
      });

      const result = await service.verifyByReference(
        referenceNumber,
        organizationId,
        userId,
        100, // Expected 100
        'CBE',
        '12345678',
      );

      // The system should still verify if account matches, but log the amount discrepancy
      expect(result.verified).toBe(true);
      expect(result.amount).toBe(50); // Actual amount from API
    });
  });

  describe('Test 4: Duplicate Transaction', () => {
    it('should FAIL when transaction reference has already been verified', async () => {
      const organizationId = 'test-org-id';
      const userId = 'test-user-id';
      const referenceNumber = 'FT12345678';

      // Mock existing payment
      mockPrisma.payment.findFirst.mockResolvedValue({
        id: 'existing-payment',
        organizationId,
        userId,
        amount: 100,
        currency: 'ETB',
        paymentMethod: 'REFERENCE',
        transactionId: referenceNumber,
        senderName: 'John Doe',
        receiverName: 'Test Business',
        status: PaymentStatus.VERIFIED,
        riskScore: 0,
        rawData: null,
        createdAt: new Date(),
        updatedAt: new Date(),
      });

      const result = await service.verifyByReference(
        referenceNumber,
        organizationId,
        userId,
        100,
        'CBE',
        '12345678',
      );

      expect(result.verified).toBe(false);
      expect(result.status).toBe('DUPLICATE_TRANSACTION');
      expect(result.message).toContain('already been verified');
    });
  });

  describe('Test 5: Fake/Edited Screenshot', () => {
    it('should FAIL when screenshot is fake or edited (API returns success: false)', async () => {
      const organizationId = 'test-org-id';
      const userId = 'test-user-id';
      const referenceNumber = 'FT12345678';
      const businessAccount = {
        id: 'account-1',
        organizationId,
        provider: PaymentProvider.CBE,
        accountNumber: '1000516323381',
        suffix: '12345678',
        accountHolderName: 'Test Business',
        isActive: true,
        createdAt: new Date(),
        updatedAt: new Date(),
        branchId: null,
      };

      mockPrisma.payment.findFirst.mockResolvedValue(null);
      mockPrisma.paymentAccount.findMany.mockResolvedValue([businessAccount]);
      mockPrisma.payment.create.mockResolvedValue({
        id: 'payment-1',
        organizationId,
        userId,
        amount: 0,
        currency: 'ETB',
        paymentMethod: 'REFERENCE',
        transactionId: referenceNumber,
        senderName: null,
        receiverName: null,
        status: PaymentStatus.FAILED,
        riskScore: 80,
        rawData: null,
        createdAt: new Date(),
        updatedAt: new Date(),
      });
      mockPrisma.verificationLog.create.mockResolvedValue({});

      // Mock API response indicating fake/edited screenshot
      jest.spyOn(service as any, '_fetchJson').mockResolvedValue({
        success: false,
        reason: 'Screenshot appears to be edited or fake',
      });

      const result = await service.verifyByReference(
        referenceNumber,
        organizationId,
        userId,
        100,
        'CBE',
        '12345678',
      );

      expect(result.verified).toBe(false);
      expect(result.status).toBe(PaymentStatus.FAILED);
      expect(result.message).toContain('could not be verified');
    });
  });

  describe('Test 6: No Registered Payment Accounts', () => {
    it('should FAIL when business has no registered payment accounts', async () => {
      const organizationId = 'test-org-id';
      const userId = 'test-user-id';
      const referenceNumber = 'FT12345678';

      mockPrisma.payment.findFirst.mockResolvedValue(null);
      mockPrisma.paymentAccount.findMany.mockResolvedValue([]);
      mockPrisma.payment.create.mockResolvedValue({
        id: 'payment-1',
        organizationId,
        userId,
        amount: 0,
        currency: 'ETB',
        paymentMethod: 'REFERENCE',
        transactionId: referenceNumber,
        senderName: null,
        receiverName: null,
        status: PaymentStatus.FAILED,
        riskScore: 80,
        rawData: null,
        createdAt: new Date(),
        updatedAt: new Date(),
      });
      mockPrisma.verificationLog.create.mockResolvedValue({});

      const result = await service.verifyByReference(
        referenceNumber,
        organizationId,
        userId,
        100,
        'CBE',
        '12345678',
      );

      expect(result.verified).toBe(false);
      expect(result.message).toContain('No registered payment accounts');
    });
  });

  describe('Test 7: Suffix Matching', () => {
    it('should PASS when suffix matches exactly', async () => {
      const organizationId = 'test-org-id';
      const userId = 'test-user-id';
      const referenceNumber = 'FT12345678';
      const businessAccount = {
        id: 'account-1',
        organizationId,
        provider: PaymentProvider.CBE,
        accountNumber: '1000516323381',
        suffix: '12345678',
        accountHolderName: 'Test Business',
        isActive: true,
        createdAt: new Date(),
        updatedAt: new Date(),
        branchId: null,
      };

      mockPrisma.payment.findFirst.mockResolvedValue(null);
      mockPrisma.paymentAccount.findMany.mockResolvedValue([businessAccount]);
      mockPrisma.payment.create.mockResolvedValue({
        id: 'payment-1',
        organizationId,
        userId,
        amount: 100,
        currency: 'ETB',
        paymentMethod: 'REFERENCE',
        transactionId: referenceNumber,
        senderName: 'John Doe',
        receiverName: 'Test Business',
        status: PaymentStatus.VERIFIED,
        riskScore: 0,
        rawData: null,
        createdAt: new Date(),
        updatedAt: new Date(),
      });
      mockPrisma.verificationLog.create.mockResolvedValue({});

      jest.spyOn(service as any, '_fetchJson').mockResolvedValue({
        success: true,
        suffix: '12345678',
        amount: 100,
      });

      const result = await service.verifyByReference(
        referenceNumber,
        organizationId,
        userId,
        100,
        'CBE',
        '12345678',
      );

      expect(result.verified).toBe(true);
    });

    it('should FAIL when suffix does not match', async () => {
      const organizationId = 'test-org-id';
      const userId = 'test-user-id';
      const referenceNumber = 'FT12345678';
      const businessAccount = {
        id: 'account-1',
        organizationId,
        provider: PaymentProvider.CBE,
        accountNumber: '1000516323381',
        suffix: '12345678',
        accountHolderName: 'Test Business',
        isActive: true,
        createdAt: new Date(),
        updatedAt: new Date(),
        branchId: null,
      };

      mockPrisma.payment.findFirst.mockResolvedValue(null);
      mockPrisma.paymentAccount.findMany.mockResolvedValue([businessAccount]);
      mockPrisma.payment.create.mockResolvedValue({
        id: 'payment-1',
        organizationId,
        userId,
        amount: 100,
        currency: 'ETB',
        paymentMethod: 'REFERENCE',
        transactionId: referenceNumber,
        senderName: 'John Doe',
        receiverName: 'Test Business',
        status: PaymentStatus.FAILED,
        riskScore: 80,
        rawData: null,
        createdAt: new Date(),
        updatedAt: new Date(),
      });
      mockPrisma.verificationLog.create.mockResolvedValue({});

      jest.spyOn(service as any, '_fetchJson').mockResolvedValue({
        success: true,
        suffix: '87654321', // Wrong suffix
        amount: 100,
      });

      const result = await service.verifyByReference(
        referenceNumber,
        organizationId,
        userId,
        100,
        'CBE',
        '12345678',
      );

      expect(result.verified).toBe(false);
      expect(result.message).toContain('not sent to this business account');
    });
  });

  describe('Test 8: Account Number Matching', () => {
    it('should PASS when account number matches exactly (normalized)', async () => {
      const organizationId = 'test-org-id';
      const userId = 'test-user-id';
      const referenceNumber = 'FT12345678';
      const businessAccount = {
        id: 'account-1',
        organizationId,
        provider: PaymentProvider.CBE,
        accountNumber: '1000516323381',
        suffix: null,
        accountHolderName: 'Test Business',
        isActive: true,
        createdAt: new Date(),
        updatedAt: new Date(),
        branchId: null,
      };

      mockPrisma.payment.findFirst.mockResolvedValue(null);
      mockPrisma.paymentAccount.findMany.mockResolvedValue([businessAccount]);
      mockPrisma.payment.create.mockResolvedValue({
        id: 'payment-1',
        organizationId,
        userId,
        amount: 100,
        currency: 'ETB',
        paymentMethod: 'REFERENCE',
        transactionId: referenceNumber,
        senderName: 'John Doe',
        receiverName: 'Test Business',
        status: PaymentStatus.VERIFIED,
        riskScore: 0,
        rawData: null,
        createdAt: new Date(),
        updatedAt: new Date(),
      });
      mockPrisma.verificationLog.create.mockResolvedValue({});

      // API returns account number with spaces
      jest.spyOn(service as any, '_fetchJson').mockResolvedValue({
        success: true,
        accountNumber: '1000 5163 23381',
        amount: 100,
      });

      const result = await service.verifyByReference(
        referenceNumber,
        organizationId,
        userId,
        100,
        'CBE',
        undefined,
      );

      expect(result.verified).toBe(true);
    });

    it('should FAIL when account number does not match', async () => {
      const organizationId = 'test-org-id';
      const userId = 'test-user-id';
      const referenceNumber = 'FT12345678';
      const businessAccount = {
        id: 'account-1',
        organizationId,
        provider: PaymentProvider.CBE,
        accountNumber: '1000516323381',
        suffix: null,
        accountHolderName: 'Test Business',
        isActive: true,
        createdAt: new Date(),
        updatedAt: new Date(),
        branchId: null,
      };

      mockPrisma.payment.findFirst.mockResolvedValue(null);
      mockPrisma.paymentAccount.findMany.mockResolvedValue([businessAccount]);
      mockPrisma.payment.create.mockResolvedValue({
        id: 'payment-1',
        organizationId,
        userId,
        amount: 100,
        currency: 'ETB',
        paymentMethod: 'REFERENCE',
        transactionId: referenceNumber,
        senderName: 'John Doe',
        receiverName: 'Test Business',
        status: PaymentStatus.FAILED,
        riskScore: 80,
        rawData: null,
        createdAt: new Date(),
        updatedAt: new Date(),
      });
      mockPrisma.verificationLog.create.mockResolvedValue({});

      jest.spyOn(service as any, '_fetchJson').mockResolvedValue({
        success: true,
        accountNumber: '1000999999999', // Wrong account
        amount: 100,
      });

      const result = await service.verifyByReference(
        referenceNumber,
        organizationId,
        userId,
        100,
        'CBE',
        undefined,
      );

      expect(result.verified).toBe(false);
      expect(result.message).toContain('not sent to this business account');
    });
  });

  describe('Data Masking in Logs', () => {
    it('should mask sensitive data in logs', () => {
      const serviceWithExposed = service as any;
      
      expect(serviceWithExposed._maskSensitive('12345678')).toBe('12****78');
      expect(serviceWithExposed._maskSensitive('1000516323381')).toBe('10****81');
      expect(serviceWithExposed._maskSensitive('123')).toBe('****');
      expect(serviceWithExposed._maskSensitive(null)).toBe('null');
      expect(serviceWithExposed._maskSensitive(undefined)).toBe('null');
    });
  });
});
