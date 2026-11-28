import { Test } from '@nestjs/testing';
import { ServiceUnavailableException } from '@nestjs/common';
import { HealthController } from './health.controller';
import { PrismaService } from '../prisma/prisma.service';

describe('HealthController', () => {
  let controller: HealthController;
  const prisma = { isHealthy: jest.fn() };

  beforeEach(async () => {
    jest.resetAllMocks();
    const moduleRef = await Test.createTestingModule({
      controllers: [HealthController],
      providers: [{ provide: PrismaService, useValue: prisma }],
    }).compile();
    controller = moduleRef.get(HealthController);
  });

  it('returns 200 with a coarse status when the database is reachable', async () => {
    prisma.isHealthy.mockResolvedValue(true);

    const body = await controller.check();

    expect(body.status).toBe('ok');
    expect(body.database).toBe('up');
    expect(typeof body.uptime).toBe('number');
  });

  it('throws 503 without leaking internals when the database is down', async () => {
    prisma.isHealthy.mockResolvedValue(false);

    await expect(controller.check()).rejects.toBeInstanceOf(
      ServiceUnavailableException,
    );

    await controller.check().catch((error: ServiceUnavailableException) => {
      // Only a coarse body is exposed — no driver errors or connection info.
      expect(error.getResponse()).toEqual({
        status: 'error',
        database: 'down',
      });
    });
  });
});
