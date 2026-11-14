import { Test, TestingModule } from '@nestjs/testing';
import { ExecutionContext } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { JwtService } from '@nestjs/jwt';
import {
  getOptionsToken,
  getStorageToken,
  ThrottlerException,
  ThrottlerStorageService,
} from '@nestjs/throttler';
import { OrgThrottlerGuard } from './org-throttler.guard';

describe('OrgThrottlerGuard', () => {
  let guard: OrgThrottlerGuard;
  let nestJwtService: JwtService;
  const secret = 'test-secret-that-is-long-enough-32chars';

  function makeContext(req: Record<string, unknown>): ExecutionContext {
    return {
      getHandler: () => function handler() {},
      getClass: () => class TestClass {},
      switchToHttp: () => ({
        getRequest: () => req,
        getResponse: () => ({ header: jest.fn() }),
      }),
    } as unknown as ExecutionContext;
  }

  async function buildInitializedGuard(
    options: any,
  ): Promise<OrgThrottlerGuard> {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        OrgThrottlerGuard,
        { provide: getOptionsToken(), useValue: options },
        { provide: getStorageToken(), useClass: ThrottlerStorageService },
        Reflector,
        { provide: JwtService, useValue: nestJwtService },
      ],
    }).compile();
    // ThrottlerGuard parses its throttler list in onModuleInit; compile() alone
    // does not run lifecycle hooks.
    const g = module.get<OrgThrottlerGuard>(OrgThrottlerGuard);
    await g.onModuleInit();
    return g;
  }

  beforeEach(() => {
    nestJwtService = new JwtService({ secret });
  });

  describe('getTracker', () => {
    const track = (g: OrgThrottlerGuard, req: Record<string, unknown>) =>
      g['getTracker'](req);

    it('uses the JWT-authenticated organization when req.user is present', async () => {
      guard = await buildInitializedGuard([
        { name: 'default', ttl: 1000, limit: 10 },
      ]);
      const req = { user: { organizationId: 'org-1' } };
      await expect(track(guard, req)).resolves.toBe('org:org-1');
    });

    it('extracts the organization from a valid Bearer token when user is not yet attached', async () => {
      guard = await buildInitializedGuard([
        { name: 'default', ttl: 1000, limit: 10 },
      ]);
      const token = nestJwtService.sign({
        sub: 'user-1',
        organizationId: 'org-2',
        role: 'CASHIER',
      });
      await expect(
        track(guard, { headers: { authorization: `Bearer ${token}` } }),
      ).resolves.toBe('org:org-2');
    });

    it('falls back to the client IP for an invalid or forged token', async () => {
      guard = await buildInitializedGuard([
        { name: 'default', ttl: 1000, limit: 10 },
      ]);
      await expect(
        track(guard, {
          headers: { authorization: 'Bearer forged' },
          ip: '10.0.0.1',
        }),
      ).resolves.toBe('ip:10.0.0.1');
    });

    it('falls back to the client IP when there is no authentication', async () => {
      guard = await buildInitializedGuard([
        { name: 'default', ttl: 1000, limit: 10 },
      ]);
      await expect(track(guard, { ip: '10.0.0.2' })).resolves.toBe(
        'ip:10.0.0.2',
      );
    });

    it('never trusts an unverified token payload claiming another organization', async () => {
      // Forged JWT: tampered payload, garbage signature
      const forged = `.${Buffer.from(
        JSON.stringify({ sub: 'x', organizationId: 'org-victim' }),
      ).toString('base64url')}.fakesig`;
      guard = await buildInitializedGuard([
        { name: 'default', ttl: 1000, limit: 10 },
      ]);
      await expect(
        track(guard, {
          headers: { authorization: `Bearer ${forged}` },
          ip: '10.0.0.3',
        }),
      ).resolves.toBe('ip:10.0.0.3');
    });
  });

  describe('request limiting (real storage)', () => {
    it('allows requests below the configured limit and throws HTTP 429 beyond it', async () => {
      const limit = 3;
      guard = await buildInitializedGuard([
        { name: 'default', ttl: 1000, limit },
      ]);
      const ctx = makeContext({ ip: '192.0.2.1' });

      for (let i = 0; i < limit; i++) {
        await expect(guard.canActivate(ctx)).resolves.toBe(true);
      }
      await expect(guard.canActivate(ctx)).rejects.toBeInstanceOf(
        ThrottlerException,
      );
      await expect(guard.canActivate(ctx)).rejects.toMatchObject({
        status: 429,
      });
    });

    it('tracks organizations separately from other organizations and IPs', async () => {
      const limit = 2;
      guard = await buildInitializedGuard([
        { name: 'default', ttl: 1000, limit },
      ]);

      const orgA = makeContext({ user: { organizationId: 'org-a' } });
      const orgB = makeContext({ user: { organizationId: 'org-b' } });
      const anon = makeContext({ ip: '192.0.2.9' });

      // Exhaust org-a's bucket
      await expect(guard.canActivate(orgA)).resolves.toBe(true);
      await expect(guard.canActivate(orgA)).resolves.toBe(true);
      await expect(guard.canActivate(orgA)).rejects.toBeInstanceOf(
        ThrottlerException,
      );

      // Other buckets are unaffected
      await expect(guard.canActivate(orgB)).resolves.toBe(true);
      await expect(guard.canActivate(anon)).resolves.toBe(true);
    });

    it('blocks again while the window is still active (429 after throttling)', async () => {
      guard = await buildInitializedGuard([
        { name: 'default', ttl: 1000, limit: 1 },
      ]);
      const ctx = makeContext({ ip: '192.0.2.5' });
      await expect(guard.canActivate(ctx)).resolves.toBe(true);
      await expect(guard.canActivate(ctx)).rejects.toBeInstanceOf(
        ThrottlerException,
      );
      await expect(guard.canActivate(ctx)).rejects.toBeInstanceOf(
        ThrottlerException,
      );
    });
  });
});
