import { UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService as NestJwtService } from '@nestjs/jwt';
import * as crypto from 'crypto';
import {
  BUSINESS_SELECTION_ORG_ID,
  BUSINESS_SELECTION_ROLE,
  BUSINESS_SELECTION_TTL_MS,
  JwtService,
} from './jwt.service';

const ACCESS_SECRET = 'a'.repeat(64);
const REFRESH_SECRET = 'b'.repeat(64);

function hashToken(token: string) {
  return crypto.createHash('sha256').update(token).digest('hex');
}

function makeConfig() {
  return new ConfigService({
    JWT_ACCESS_SECRET: ACCESS_SECRET,
    JWT_REFRESH_SECRET: REFRESH_SECRET,
  });
}

function makeChallenge(overrides: Record<string, unknown> = {}) {
  return {
    id: 'challenge-1',
    userId: 'user-1',
    token: hashToken('challenge-token'),
    organizationId: BUSINESS_SELECTION_ORG_ID,
    role: BUSINESS_SELECTION_ROLE,
    expiresAt: new Date(Date.now() + BUSINESS_SELECTION_TTL_MS),
    ...overrides,
  };
}

describe('JwtService — business selection challenges', () => {
  let service: JwtService;
  let prisma: { refreshToken: Record<string, jest.Mock> };

  beforeEach(() => {
    prisma = {
      refreshToken: {
        deleteMany: jest.fn().mockResolvedValue({ count: 1 }),
        create: jest
          .fn()
          .mockImplementation(({ data }) =>
            Promise.resolve({ id: 'challenge-1', ...data }),
          ),
        findUnique: jest.fn().mockResolvedValue(null),
        findMany: jest.fn().mockResolvedValue([]),
        delete: jest.fn().mockResolvedValue({}),
      },
    };
    service = new JwtService(
      { sign: jest.fn(), verify: jest.fn() } as unknown as NestJwtService,
      makeConfig(),
      prisma as never,
    );
  });

  it('creates a hashed, short-lived challenge bound to the user', async () => {
    const challenge =
      await service.generateBusinessSelectionChallenge('user-1');

    expect(typeof challenge).toBe('string');
    expect(challenge.length).toBeGreaterThan(32);
    expect(prisma.refreshToken.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          userId: 'user-1',
          organizationId: BUSINESS_SELECTION_ORG_ID,
          role: BUSINESS_SELECTION_ROLE,
        }),
      }),
    );
    const data = prisma.refreshToken.create.mock.calls[0][0].data;
    expect(data.token).toBe(hashToken(challenge));
    expect(data.token).not.toBe(challenge);
    expect(data.expiresAt.getTime() - Date.now()).toBeLessThanOrEqual(
      BUSINESS_SELECTION_TTL_MS,
    );
  });

  it('rejects a missing selection token', async () => {
    await expect(
      service.consumeBusinessSelectionChallenge(''),
    ).rejects.toBeInstanceOf(UnauthorizedException);
    expect(prisma.refreshToken.findUnique).not.toHaveBeenCalled();
  });

  it('rejects an invalid selection token', async () => {
    prisma.refreshToken.findUnique.mockResolvedValueOnce(null);
    await expect(
      service.consumeBusinessSelectionChallenge('not-a-challenge'),
    ).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it('rejects and deletes an expired challenge', async () => {
    prisma.refreshToken.findUnique.mockResolvedValueOnce(
      makeChallenge({ expiresAt: new Date(Date.now() - 1000) }),
    );

    await expect(
      service.consumeBusinessSelectionChallenge('challenge-token'),
    ).rejects.toThrow(/expired/i);
    expect(prisma.refreshToken.deleteMany).toHaveBeenCalledWith({
      where: { id: 'challenge-1' },
    });
  });

  it('consumes a valid challenge exactly once', async () => {
    prisma.refreshToken.findUnique.mockResolvedValue(makeChallenge());
    prisma.refreshToken.deleteMany
      .mockResolvedValueOnce({ count: 1 })
      .mockResolvedValueOnce({ count: 0 });

    await expect(
      service.consumeBusinessSelectionChallenge('challenge-token'),
    ).resolves.toBe('user-1');

    await expect(
      service.consumeBusinessSelectionChallenge('challenge-token'),
    ).rejects.toThrow(/already used/i);
  });

  it('cannot use a business selection challenge as a refresh token', async () => {
    prisma.refreshToken.findUnique.mockResolvedValueOnce(
      makeChallenge({
        user: {
          id: 'user-1',
          userAssignments: [
            {
              organizationId: BUSINESS_SELECTION_ORG_ID,
              role: BUSINESS_SELECTION_ROLE,
            },
          ],
        },
      }),
    );

    await expect(service.refreshTokens('challenge-token')).rejects.toThrow(
      /cannot be used as refresh tokens/i,
    );
    expect(prisma.refreshToken.delete).toHaveBeenCalledWith({
      where: { id: 'challenge-1' },
    });
  });
});
