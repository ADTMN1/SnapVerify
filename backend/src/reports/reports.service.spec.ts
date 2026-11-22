import { BadRequestException } from '@nestjs/common';
import { ReportsService } from './reports.service';

const makePayment = (overrides: Record<string, unknown> = {}) => ({
  id: 'p1',
  amount: 100,
  currency: 'ETB',
  status: 'VERIFIED',
  paymentMethod: 'cbe',
  transactionId: 'FT1',
  senderName: 'Payer',
  receiverName: 'Receiver',
  riskScore: 0,
  createdAt: new Date('2026-01-15T10:00:00.000Z'),
  userId: 'u1',
  user: { id: 'u1', fullName: 'Alice', username: null, phone: null },
  ...overrides,
});

describe('ReportsService', () => {
  let service: ReportsService;
  let findMany: jest.Mock;

  beforeEach(() => {
    findMany = jest.fn();
    service = new ReportsService({ payment: { findMany } } as any);
  });

  it('aggregates real payments into summary and breakdowns', async () => {
    findMany.mockResolvedValue([
      makePayment(),
      makePayment({ id: 'p2', status: 'FAILED', amount: 50, riskScore: 80 }),
      makePayment({
        id: 'p3',
        status: 'VERIFIED',
        amount: 200,
        userId: null,
        user: null,
      }),
    ]);

    const result = await service.getSummary({
      organizationId: 'org-1',
      role: 'OWNER',
      from: '2026-01-01',
      to: '2026-01-31',
    });

    expect(result.summary.total).toBe(3);
    expect(result.summary.verified).toBe(2);
    expect(result.summary.failed).toBe(1);
    expect(result.summary.verifiedAmount).toBe(300);
    expect(result.summary.totalAmount).toBe(350);
    expect(result.summary.averageAmount).toBe(150);
    expect(result.summary.highRisk).toBe(1);
    expect(result.byStatus).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ status: 'VERIFIED', count: 2, amount: 300 }),
        expect.objectContaining({ status: 'FAILED', count: 1, amount: 50 }),
      ]),
    );
    expect(result.byStaff[0]).toEqual(
      expect.objectContaining({ userId: 'u1', name: 'Alice', count: 2 }),
    );
    expect(result.recent).toHaveLength(3);
  });

  it('scopes cashiers/waiters to their own userId', async () => {
    findMany.mockResolvedValue([]);
    await service.getSummary({
      organizationId: 'org-1',
      userId: 'u1',
      role: 'CASHIER',
      from: '2026-01-01',
      to: '2026-01-31',
    });
    expect(findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          organizationId: 'org-1',
          userId: 'u1',
        }),
      }),
    );
  });

  it('does not scope owners/managers by userId', async () => {
    findMany.mockResolvedValue([]);
    await service.getSummary({
      organizationId: 'org-1',
      userId: 'u1',
      role: 'MANAGER',
      from: '2026-01-01',
      to: '2026-01-31',
    });
    const where = findMany.mock.calls[0][0].where;
    expect(where.userId).toBeUndefined();
  });

  it('rejects invalid dates', async () => {
    await expect(
      service.getSummary({
        organizationId: 'org-1',
        from: 'bad',
        to: '2026-01-31',
      }),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('rejects a from date after the to date', async () => {
    await expect(
      service.getSummary({
        organizationId: 'org-1',
        from: '2026-02-01',
        to: '2026-01-01',
      }),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('returns zeros for an empty range', async () => {
    findMany.mockResolvedValue([]);
    const result = await service.getSummary({
      organizationId: 'org-1',
      from: '2026-01-01',
      to: '2026-01-31',
    });
    expect(result.summary.total).toBe(0);
    expect(result.summary.verifiedAmount).toBe(0);
    expect(result.byStatus).toEqual([]);
  });
});
