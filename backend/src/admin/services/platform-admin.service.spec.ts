import { validate } from 'class-validator';
import { PlatformAdminService } from './platform-admin.service';
import {
  CreateSubscriptionPlanDto,
  UpdateSubscriptionPlanDto,
} from '../dto/subscription-plan.dto';

function build(existing: Record<string, unknown> | null = null) {
  const prisma = {
    subscriptionPlan: {
      findUnique: jest.fn().mockResolvedValue(existing),
      create: jest.fn().mockImplementation(({ data }) =>
        Promise.resolve({
          ...data,
          createdAt: new Date(),
          updatedAt: new Date(),
        }),
      ),
      update: jest.fn().mockImplementation(({ data }) =>
        Promise.resolve({ ...existing, ...data }),
      ),
    },
  };
  return { service: new PlatformAdminService(prisma as never), prisma };
}

describe('PlatformAdminService subscription plan durations', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('creates a five-month plan with the duration stored in months', async () => {
    const { service, prisma } = build();

    const created = await service.createPlan({
      name: '5 Months',
      price: 60000,
      durationMonths: 5,
    });

    expect(created.durationMonths).toBe(5);
    expect(created.durationDays).toBeNull();
    expect(created.isLifetime).toBe(false);
    expect(prisma.subscriptionPlan.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        id: '5_months',
        name: '5 Months',
        price: 60000,
        durationDays: null,
        durationMonths: 5,
        isLifetime: false,
      }),
    });
  });

  it('creates an explicitly configured lifetime plan with no duration', async () => {
    const { service, prisma } = build();

    const created = await service.createPlan({
      name: 'Lifetime',
      price: 0,
      isLifetime: true,
    });

    expect(created.isLifetime).toBe(true);
    expect(prisma.subscriptionPlan.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        durationDays: null,
        durationMonths: null,
        isLifetime: true,
      }),
    });
  });

  it.each([
    ['missing duration', {}],
    ['explicit non-lifetime with no duration', { isLifetime: false }],
    ['zero months', { durationMonths: 0 }],
    ['negative days', { durationDays: -1 }],
  ])('rejects %s when creating a plan', async (_label, duration) => {
    const { service, prisma } = build();

    await expect(
      service.createPlan({ name: 'Invalid', price: 100, ...duration }),
    ).rejects.toThrow();
    expect(prisma.subscriptionPlan.create).not.toHaveBeenCalled();
  });

  it('rejects a lifetime plan that also has a duration', async () => {
    const { service } = build();
    await expect(
      service.createPlan({
        name: 'Broken Lifetime',
        price: 100,
        durationMonths: 5,
        isLifetime: true,
      }),
    ).rejects.toThrow(/Lifetime plans cannot have a duration/);
  });

  it('leaves legacy no-duration plans unchanged on a partial update', async () => {
    const legacy = {
      id: 'free',
      name: 'Free',
      price: 0,
      currency: 'ETB',
      durationDays: null,
      durationMonths: null,
      isLifetime: false,
      isActive: true,
      sortOrder: 0,
    };
    const { service, prisma } = build(legacy);

    await service.updatePlan('free', { name: 'Free Plan' });

    expect(prisma.subscriptionPlan.update).toHaveBeenCalledWith({
      where: { id: 'free' },
      data: { name: 'Free Plan' },
    });
  });

  it('rejects an update that would leave both duration fields set', async () => {
    const existing = {
      id: 'monthly',
      name: 'Monthly',
      price: 1500,
      currency: 'ETB',
      durationDays: 30,
      durationMonths: null,
      isLifetime: false,
      isActive: true,
      sortOrder: 1,
    };
    const { service, prisma } = build(existing);

    await expect(
      service.updatePlan('monthly', { durationMonths: 5 }),
    ).rejects.toThrow(/either durationDays or durationMonths/);
    expect(prisma.subscriptionPlan.update).not.toHaveBeenCalled();
  });

  it('validates the create DTO for month durations', async () => {
    const dto = Object.assign(new CreateSubscriptionPlanDto(), {
      name: '5 Months',
      price: 60000,
      durationMonths: 5,
    });
    expect(await validate(dto)).toEqual([]);

    const invalid = Object.assign(new CreateSubscriptionPlanDto(), {
      name: '5 Months',
      price: 60000,
      durationMonths: 0,
    });
    expect((await validate(invalid)).length).toBeGreaterThan(0);
  });

  it('validates the update DTO for lifetime plans', async () => {
    const dto = Object.assign(new UpdateSubscriptionPlanDto(), {
      durationDays: null,
      durationMonths: null,
      isLifetime: true,
    });
    expect(await validate(dto)).toEqual([]);
  });
});
