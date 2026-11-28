import { Inject, Injectable } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import {
  getOptionsToken,
  getStorageToken,
  ThrottlerGuard,
} from '@nestjs/throttler';
import type {
  ThrottlerModuleOptions,
  ThrottlerStorage,
} from '@nestjs/throttler';
import { JwtService } from '@nestjs/jwt';

/**
 * Global rate-limiting guard (Stage 1).
 *
 * Tracker resolution order:
 *   1. organizationId already attached by JwtAuthGuard (trusted JWT context)
 *   2. organizationId from a SIGNATURE-VERIFIED Bearer token — the raw payload
 *      is never trusted, so a client cannot claim another organization's
 *      bucket by forging a header
 *   3. client IP (Express `req.ip`; `trust proxy` is configured to one trusted
 *      proxy hop in bootstrap, so a single platform proxy hop is honored)
 *
 * SECURITY LIMITATION (documented, by design): authenticated requests are
 * tracked per ORGANIZATION, so all staff of one merchant share one bucket.
 * This bounds abuse from any compromised or malicious employee account to the
 * merchant's own quota, at the cost of losing a per-IP layer for
 * authenticated traffic. Requests without a valid JWT are IP-tracked and are
 * additionally rejected by JwtAuthGuard.
 *
 * The ThrottlerStorage default is in-memory: limits are enforced per backend
 * instance. Multi-instance deployments need a shared storage (see remaining
 * limitations in the Stage 1 report).
 */
@Injectable()
export class OrgThrottlerGuard extends ThrottlerGuard {
  constructor(
    @Inject(getOptionsToken()) options: ThrottlerModuleOptions,
    @Inject(getStorageToken()) storageService: ThrottlerStorage,
    reflector: Reflector,
    private readonly jwtService: JwtService,
  ) {
    super(options, storageService, reflector);
  }

  // Signature matches the base class (Promise-returning); the implementation
  // is synchronous because both the JWT verify and IP lookup are synchronous.
  protected getTracker(req: Record<string, any>): Promise<string> {
    const organizationId =
      req?.user?.organizationId ?? this.organizationIdFromBearer(req);
    if (organizationId) return Promise.resolve(`org:${organizationId}`);
    return Promise.resolve(`ip:${this.clientIp(req)}`);
  }

  private organizationIdFromBearer(req: Record<string, any>): string | null {
    const header = req?.headers?.authorization;
    if (typeof header !== 'string' || !header.startsWith('Bearer ')) {
      return null;
    }
    try {
      // verify() checks the signature and expiry; a forged or expired token
      // falls back to IP tracking (and is later rejected by JwtAuthGuard).
      const payload = this.jwtService.verify(header.slice(7));
      return typeof payload?.organizationId === 'string'
        ? payload.organizationId
        : null;
    } catch {
      return null;
    }
  }

  private clientIp(req: Record<string, any>): string {
    return req?.ip ?? req?.socket?.remoteAddress ?? 'unknown';
  }
}
