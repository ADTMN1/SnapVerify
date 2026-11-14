import { Test } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { Reflector } from '@nestjs/core';
import { ExecutionContext } from '@nestjs/common';
import { JwtAuthGuard } from './auth/guards/jwt-auth.guard';
import { resolveAllowedOrigins, resolveCorsConfig } from './main';

describe('CORS configuration', () => {
  it('rejects wildcard origins', () => {
    expect(() => resolveAllowedOrigins('*', 'development')).toThrow(
      /wildcard/i,
    );
  });

  it('requires explicit origins in production', () => {
    expect(() => resolveAllowedOrigins('', 'production')).toThrow(
      /ALLOWED_ORIGINS/,
    );
  });

  it('parses explicit allow-list and keeps credentials off by default', () => {
    expect(
      resolveAllowedOrigins(
        'https://app.example.com, http://localhost:3000',
        'production',
      ),
    ).toEqual(['https://app.example.com', 'http://localhost:3000']);
    const cfg = resolveCorsConfig({
      NODE_ENV: 'production',
      ALLOWED_ORIGINS: 'https://app.example.com',
    });
    expect(cfg.credentials).toBe(false);
  });
});

describe('JwtAuthGuard configuration', () => {
  it('fails closed when JWT_ACCESS_SECRET is missing', async () => {
    const moduleRef = await Test.createTestingModule({
      providers: [
        JwtAuthGuard,
        {
          provide: ConfigService,
          useValue: {
            getOrThrow: jest.fn(() => {
              throw new Error('missing');
            }),
          },
        },
        { provide: JwtService, useValue: { verify: jest.fn() } },
        {
          provide: Reflector,
          useValue: { getAllAndOverride: jest.fn(() => false) },
        },
      ],
    }).compile();

    const guard = moduleRef.get(JwtAuthGuard);
    const ctx = {
      getHandler: () => ({}),
      getClass: () => ({}),
      switchToHttp: () => ({
        getRequest: () => ({ headers: { authorization: 'Bearer token' } }),
      }),
    } as unknown as ExecutionContext;

    expect(() => guard.canActivate(ctx)).toThrow();
  });
});
