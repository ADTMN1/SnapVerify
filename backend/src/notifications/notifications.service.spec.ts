import { NotificationsService } from './notifications.service';

const payment = (overrides: Record<string, unknown> = {}) => ({
  id: 'p1',
  amount: 100,
  currency: 'ETB',
  status: 'VERIFIED',
  transactionId: 'FT1',
  senderName: 'Payer',
  createdAt: new Date('2026-01-15T10:00:00.000Z'),
  ...overrides,
});

const invitation = (overrides: Record<string, unknown> = {}) => ({
  id: 'i1',
  fullName: 'Alice',
  username: null,
  role: 'CASHIER',
  status: 'PENDING',
  createdAt: new Date('2026-01-16T10:00:00.000Z'),
  ...overrides,
});

describe('NotificationsService', () => {
  const prisma: any = {
    payment: { findMany: jest.fn() },
    invitation: { findMany: jest.fn() },
    user: { findUnique: jest.fn(), update: jest.fn() },
  };
  const service = new NotificationsService(prisma);

  beforeEach(() => {
    jest.clearAllMocks();
    prisma.user.findUnique.mockResolvedValue({ notificationsReadAt: null });
  });

  it('maps payments and invitations into a sorted feed', async () => {
    prisma.payment.findMany.mockResolvedValue([payment()]);
    prisma.invitation.findMany.mockResolvedValue([invitation()]);

    const result = await service.getFeed({
      organizationId: 'org-1',
      userId: 'u1',
      role: 'OWNER',
    });

    expect(result.notifications).toHaveLength(2);
    expect(result.unreadCount).toBe(2);
    expect(result.notifications[0]).toEqual(
      expect.objectContaining({
        id: 'invitation:i1',
        type: 'invitation_created',
      }),
    );
    expect(result.notifications[1]).toEqual(
      expect.objectContaining({
        id: 'payment:p1',
        type: 'payment_verified',
        body: expect.stringContaining('FT1'),
      }),
    );
  });

  it('marks items read when they are older than the watermark', async () => {
    prisma.payment.findMany.mockResolvedValue([payment()]);
    prisma.invitation.findMany.mockResolvedValue([]);
    prisma.user.findUnique.mockResolvedValue({
      notificationsReadAt: new Date('2026-02-01T00:00:00.000Z'),
    });

    const result = await service.getFeed({
      organizationId: 'org-1',
      userId: 'u1',
      role: 'OWNER',
    });

    expect(result.notifications[0].read).toBe(true);
    expect(result.unreadCount).toBe(0);
  });

  it('scopes non-privileged roles to their own payments and skips invitations', async () => {
    prisma.payment.findMany.mockResolvedValue([]);
    prisma.invitation.findMany.mockResolvedValue([]);

    await service.getFeed({
      organizationId: 'org-1',
      userId: 'u1',
      role: 'CASHIER',
    });

    expect(prisma.payment.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          organizationId: 'org-1',
          userId: 'u1',
        }),
      }),
    );
    expect(prisma.invitation.findMany).not.toHaveBeenCalled();
  });

  it('does not scope owners by userId', async () => {
    prisma.payment.findMany.mockResolvedValue([]);
    prisma.invitation.findMany.mockResolvedValue([]);

    await service.getFeed({
      organizationId: 'org-1',
      userId: 'u1',
      role: 'OWNER',
    });

    const where = prisma.payment.findMany.mock.calls[0][0].where;
    expect(where.userId).toBeUndefined();
  });

  it('updates the read watermark on markAllRead', async () => {
    prisma.user.update.mockResolvedValue({});

    const result = await service.markAllRead('u1');

    expect(result.success).toBe(true);
    expect(prisma.user.update).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { id: 'u1' },
        data: { notificationsReadAt: expect.any(Date) },
      }),
    );
  });
});