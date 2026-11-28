import { ForbiddenException } from '@nestjs/common';
import { Role } from '@prisma/client';
import { PaymentController } from './payment.controller';
import { PaymentService } from './payment.service';

describe('PaymentController — branch isolation', () => {
  const mockService = {
    verifyByReference: jest.fn(),
    verifyByImage: jest.fn(),
    getVerificationHistory: jest.fn(),
  };
  const controller = new PaymentController(
    mockService as unknown as PaymentService,
  );

  const dto = { referenceNumber: 'FT123' };
  const imageFile = { buffer: Buffer.from('x'), mimetype: 'image/jpeg' };

  beforeEach(() => {
    jest.clearAllMocks();
    mockService.verifyByReference.mockResolvedValue({ verified: true });
    mockService.verifyByImage.mockResolvedValue({ verified: true });
  });

  it.each([Role.MANAGER, Role.CASHIER, Role.WAITER])(
    'rejects a branch-less %s verifyByReference without calling the service',
    async (role) => {
      const req = { user: { sub: 'user-1', organizationId: 'org-1', role } };
      await expect(
        controller.verifyByReference(dto, req as any),
      ).rejects.toBeInstanceOf(ForbiddenException);
      expect(mockService.verifyByReference).not.toHaveBeenCalled();
    },
  );

  it.each([Role.MANAGER, Role.CASHIER, Role.WAITER])(
    'rejects a branch-less %s verifyByImage without calling the service',
    async (role) => {
      const req = { user: { sub: 'user-1', organizationId: 'org-1', role } };
      await expect(
        controller.verifyByImage(imageFile as any, 'text', req as any),
      ).rejects.toBeInstanceOf(ForbiddenException);
      expect(mockService.verifyByImage).not.toHaveBeenCalled();
    },
  );

  it('allows an OWNER without a branch (unrestricted access preserved)', async () => {
    const req = {
      user: { sub: 'user-1', organizationId: 'org-1', role: Role.OWNER },
    };
    await controller.verifyByReference(dto, req as any);
    expect(mockService.verifyByReference).toHaveBeenCalledWith(
      'FT123',
      'org-1',
      'user-1',
      undefined,
      undefined,
      undefined,
      undefined,
    );
  });

  it('passes the assigned branch through for non-OWNER staff', async () => {
    const req = {
      user: {
        sub: 'user-1',
        organizationId: 'org-1',
        role: Role.MANAGER,
        branchId: 'branch-1',
      },
    };
    await controller.verifyByReference(dto, req as any);
    expect(mockService.verifyByReference).toHaveBeenCalledWith(
      'FT123',
      'org-1',
      'user-1',
      undefined,
      undefined,
      undefined,
      'branch-1',
    );
  });
});