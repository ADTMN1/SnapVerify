import { Test, TestingModule } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';
import { PaymentProvider, Role } from '@prisma/client';
import {
  BadRequestException,
  ForbiddenException,
  GoneException,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { QrService, QrAccessContext } from './qr.service';

const RAW_ACCOUNT_NUMBER = '1000516323381';
const PUBLIC_ID = 'a1b2c3d4e5f60718293a4b5c';
const OTHER_PUBLIC_ID = 'ffffffffffffffffffffffff';

const mockPrisma = {
  paymentAccount: {
    findMany: jest.fn(),
    findFirst: jest.fn(),
    findUnique: jest.fn(),
  },
  activityLog: { create: jest.fn() },
};

function account(overrides: Record<string, unknown> = {}) {
  return {
    id: 'acc-1',
    publicId: PUBLIC_ID,
    organizationId: 'org-1',
    provider: PaymentProvider.CBE,
    accountNumber: RAW_ACCOUNT_NUMBER,
    accountNumberHash: 'hmac-v1:deadbeef',
    suffix: '16323381',
    accountHolderName: 'Test Business',
    isActive: true,
    branchId: 'branch-1',
    createdAt: new Date('2026-11-01T10:00:00.000Z'),
    branch: { id: 'branch-1', name: 'Bole' },
    organization: { id: 'org-1', name: 'Test Business PLC' },
    ...overrides,
  };
}

const ownerCtx: QrAccessContext = {
  organizationId: 'org-1',
  role: Role.OWNER,
  branchId: null,
  userId: 'user-1',
  ipAddress: '10.0.0.5',
};

const managerCtx: QrAccessContext = {
  organizationId: 'org-1',
  role: Role.MANAGER,
  branchId: 'branch-1',
  userId: 'user-2',
};

async function build(): Promise<QrService> {
  const module: TestingModule = await Test.createTestingModule({
    providers: [
      QrService,
      { provide: PrismaService, useValue: mockPrisma },
      { provide: ConfigService, useValue: { get: jest.fn(() => undefined) } },
    ],
  }).compile();
  return module.get<QrService>(QrService);
}

describe('QrService', () => {
  let service: QrService;

  beforeEach(async () => {
    jest.clearAllMocks();
    mockPrisma.activityLog.create.mockResolvedValue({});
    service = await build();
  });

  // ── Listing ───────────────────────────────────────────────────────────────

  describe('listForBusiness', () => {
    it('always scopes the query to the caller’s organization', async () => {
      mockPrisma.paymentAccount.findMany.mockResolvedValue([]);

      await service.listForBusiness(ownerCtx, {});

      const where = mockPrisma.paymentAccount.findMany.mock.calls[0][0].where;
      expect(where.organizationId).toBe('org-1');
      expect(where.branchId).toBeUndefined();
    });

    it('forces a branch-scoped caller onto their own branch', async () => {
      mockPrisma.paymentAccount.findMany.mockResolvedValue([]);

      await service.listForBusiness(managerCtx, {});

      const where = mockPrisma.paymentAccount.findMany.mock.calls[0][0].where;
      expect(where.branchId).toBe('branch-1');
    });

    it('rejects a branch-scoped caller asking for another branch', async () => {
      await expect(
        service.listForBusiness(managerCtx, { branchId: 'branch-2' }),
      ).rejects.toBeInstanceOf(ForbiddenException);
      expect(mockPrisma.paymentAccount.findMany).not.toHaveBeenCalled();
    });

    it('denies a non-owner without a branch assignment', async () => {
      await expect(
        service.listForBusiness({ ...managerCtx, branchId: null }, {}),
      ).rejects.toBeInstanceOf(ForbiddenException);
    });

    it('applies provider and active filters', async () => {
      mockPrisma.paymentAccount.findMany.mockResolvedValue([]);

      await service.listForBusiness(ownerCtx, {
        provider: 'cbe',
        isActive: 'false',
      });

      const where = mockPrisma.paymentAccount.findMany.mock.calls[0][0].where;
      expect(where.provider).toBe(PaymentProvider.CBE);
      expect(where.isActive).toBe(false);
    });

    it('rejects unknown providers and non-boolean isActive values', async () => {
      await expect(
        service.listForBusiness(ownerCtx, { provider: 'NOT_A_BANK' }),
      ).rejects.toBeInstanceOf(BadRequestException);
      await expect(
        service.listForBusiness(ownerCtx, { isActive: 'maybe' }),
      ).rejects.toBeInstanceOf(BadRequestException);
    });

    it('returns masked accounts with QR links and never the raw number', async () => {
      mockPrisma.paymentAccount.findMany.mockResolvedValue([account()]);

      const result = await service.listForBusiness(
        ownerCtx,
        {},
        {
          protocol: 'https',
          headers: { host: 'api.snapverify.example' },
        },
      );

      expect(result.qrVersion).toBe('v1');
      expect(result.items).toHaveLength(1);
      expect(result.items[0].accountNumber).toBe('****3381');
      expect(result.items[0].qrUrl).toBe(
        `https://api.snapverify.example/qr/v1/${PUBLIC_ID}`,
      );
      expect(result.items[0].branch).toEqual({ id: 'branch-1', name: 'Bole' });
      expect(JSON.stringify(result)).not.toContain(RAW_ACCOUNT_NUMBER);
    });

    it('audits listing without storing sensitive data', async () => {
      mockPrisma.paymentAccount.findMany.mockResolvedValue([account()]);

      await service.listForBusiness(ownerCtx, {});

      const data = mockPrisma.activityLog.create.mock.calls[0][0].data;
      expect(data.action).toBe('QR_LIST_VIEWED');
      expect(data.organizationId).toBe('org-1');
      expect(data.userId).toBe('user-1');
      expect(JSON.stringify(data.metadata)).not.toContain(RAW_ACCOUNT_NUMBER);
    });

    it('still returns data when the audit write fails', async () => {
      mockPrisma.paymentAccount.findMany.mockResolvedValue([]);
      mockPrisma.activityLog.create.mockRejectedValue(new Error('audit down'));

      await expect(service.listForBusiness(ownerCtx, {})).resolves.toEqual({
        qrVersion: 'v1',
        items: [],
      });
    });
  });

  // ── Single account ────────────────────────────────────────────────────────

  describe('getAccountQr', () => {
    it('scopes the lookup to the organization (cross-tenant returns 404)', async () => {
      mockPrisma.paymentAccount.findFirst.mockResolvedValue(null);

      await expect(
        service.getAccountQr({ ...ownerCtx, organizationId: 'org-2' }, 'acc-1'),
      ).rejects.toBeInstanceOf(NotFoundException);

      expect(
        mockPrisma.paymentAccount.findFirst.mock.calls[0][0].where,
      ).toEqual({
        id: 'acc-1',
        organizationId: 'org-2',
      });
    });

    it('denies access to an account of another branch for branch-scoped users', async () => {
      mockPrisma.paymentAccount.findFirst.mockResolvedValue(
        account({ branchId: 'branch-2' }),
      );

      await expect(
        service.getAccountQr(managerCtx, 'acc-1'),
      ).rejects.toBeInstanceOf(ForbiddenException);
    });

    it('returns QR information for a legacy account that already has an id', async () => {
      mockPrisma.paymentAccount.findFirst.mockResolvedValue(account());

      const result = await service.getAccountQr(ownerCtx, 'acc-1', {
        protocol: 'https',
        headers: { host: 'api.snapverify.example' },
      });

      expect(result.publicId).toBe(PUBLIC_ID);
      expect(result.qrUrl).toContain(`/qr/v1/${PUBLIC_ID}`);
      expect(result.accountNumber).toBe('****3381');
    });

    it('still exposes the QR of a disabled account for management purposes', async () => {
      mockPrisma.paymentAccount.findFirst.mockResolvedValue(
        account({ isActive: false }),
      );

      const result = await service.getAccountQr(ownerCtx, 'acc-1', {
        protocol: 'https',
        headers: { host: 'api.snapverify.example' },
      });
      expect(result.isActive).toBe(false);
      expect(result.qrUrl).toContain(PUBLIC_ID);
    });

    it('omits the URL instead of inventing a domain when no origin is known', async () => {
      mockPrisma.paymentAccount.findFirst.mockResolvedValue(account());

      const result = await service.getAccountQr(ownerCtx, 'acc-1');
      expect(result.publicId).toBe(PUBLIC_ID);
      expect(result.qrUrl).toBeNull();
    });
  });

  // ── Resolve ───────────────────────────────────────────────────────────────

  describe('resolve', () => {
    it('rejects malformed identifiers without touching the database', async () => {
      await expect(
        service.resolve('not-a-public-id', ownerCtx),
      ).rejects.toBeInstanceOf(BadRequestException);
      expect(mockPrisma.paymentAccount.findUnique).not.toHaveBeenCalled();
    });

    it('returns 404 for an unknown identifier', async () => {
      mockPrisma.paymentAccount.findUnique.mockResolvedValue(null);
      await expect(service.resolve(PUBLIC_ID, ownerCtx)).rejects.toBeInstanceOf(
        NotFoundException,
      );
    });

    it('hides identifiers belonging to another organization', async () => {
      mockPrisma.paymentAccount.findUnique.mockResolvedValue(
        account({ organizationId: 'org-2' }),
      );

      await expect(service.resolve(PUBLIC_ID, ownerCtx)).rejects.toBeInstanceOf(
        NotFoundException,
      );
    });

    it('denies accounts outside the caller’s branch', async () => {
      mockPrisma.paymentAccount.findUnique.mockResolvedValue(
        account({ branchId: 'branch-2' }),
      );

      await expect(
        service.resolve(PUBLIC_ID, managerCtx),
      ).rejects.toBeInstanceOf(ForbiddenException);
    });

    it('returns 410 Gone for a disabled account', async () => {
      mockPrisma.paymentAccount.findUnique.mockResolvedValue(
        account({ isActive: false }),
      );

      await expect(service.resolve(PUBLIC_ID, ownerCtx)).rejects.toBeInstanceOf(
        GoneException,
      );
      expect(mockPrisma.activityLog.create).toHaveBeenCalled();
    });

    it('resolves an active account without exposing the raw account number', async () => {
      mockPrisma.paymentAccount.findUnique.mockResolvedValue(account());

      const result = await service.resolve(PUBLIC_ID, ownerCtx, {
        protocol: 'https',
        headers: { host: 'api.snapverify.example' },
      });

      expect(result.publicId).toBe(PUBLIC_ID);
      expect(result.provider).toBe(PaymentProvider.CBE);
      expect(result.accountNumber).toBe('****3381');
      expect(result.confirmedPayment).toBe(false);
      expect(result.notice).toMatch(/not proof of payment/i);
      expect(result.organization).toEqual({
        id: 'org-1',
        name: 'Test Business PLC',
      });
      expect(JSON.stringify(result)).not.toContain(RAW_ACCOUNT_NUMBER);
    });

    it('audits resolution with identifiers only', async () => {
      mockPrisma.paymentAccount.findUnique.mockResolvedValue(account());

      await service.resolve(PUBLIC_ID, ownerCtx);

      const data = mockPrisma.activityLog.create.mock.calls[0][0].data;
      expect(data.action).toBe('QR_RESOLVED');
      expect(data.metadata.paymentAccountId).toBe('acc-1');
      expect(data.metadata.outcome).toBe('OK');
      expect(JSON.stringify(data)).not.toContain(RAW_ACCOUNT_NUMBER);
      expect(JSON.stringify(data)).not.toContain(OTHER_PUBLIC_ID);
    });
  });
});
