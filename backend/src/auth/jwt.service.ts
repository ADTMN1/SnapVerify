import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService as NestJwtService } from '@nestjs/jwt';
import { PrismaService } from '../prisma/prisma.service';
import * as crypto from 'crypto';

interface JwtPayload {
  sub: string;
  organizationId: string;
  role: string;
  branchId?: string;
}

const MIN_JWT_SECRET_LENGTH = 32;
const MAX_REFRESH_TOKENS_PER_USER = 10;

export const DEFAULT_REFRESH_TTL_MS = 7 * 24 * 60 * 60 * 1000;
export const REMEMBERED_REFRESH_TTL_MS = 30 * 24 * 60 * 60 * 1000;
export const BUSINESS_SELECTION_ORG_ID = 'business-selection';
export const BUSINESS_SELECTION_ROLE = 'BUSINESS_SELECTION';
export const BUSINESS_SELECTION_TTL_MS = 5 * 60 * 1000;

function hashToken(token: string): string {
  return crypto.createHash('sha256').update(token).digest('hex');
}

function requireSecret(config: ConfigService, key: string): string {
  // getOrThrow raises during module initialization if the key is missing, so
  // the app can never boot with an insecure/unconfigured signing secret.
  // `config.get` would silently return undefined and let NestJWT sign with
  // `secret: undefined`, making every token forgeable.
  const value = config.getOrThrow<string>(key);
  if (value.length < MIN_JWT_SECRET_LENGTH) {
    throw new Error(
      `FATAL: ${key} must be at least ${MIN_JWT_SECRET_LENGTH} characters. ` +
        `Generate one with: node -e "console.log(require('crypto').randomBytes(64).toString('hex'))"`,
    );
  }
  return value;
}

@Injectable()
export class JwtService {
  private readonly accessSecret: string;

  constructor(
    private jwtService: NestJwtService,
    private config: ConfigService,
    private prisma: PrismaService,
  ) {
    // Validate BOTH configured secrets at startup. Refresh tokens are opaque
    // random strings (not JWTs) so only the access secret is used for signing,
    // but the refresh secret is still validated here so a misconfiguration is
    // caught immediately rather than silently ignored.
    requireSecret(this.config, 'JWT_ACCESS_SECRET');
    requireSecret(this.config, 'JWT_REFRESH_SECRET');
    this.accessSecret = this.config.getOrThrow<string>('JWT_ACCESS_SECRET');
  }

  async generateTokens(
    userId: string,
    organizationId: string,
    role: string,
    branchId?: string,
    deviceInfo?: string,
    ipAddress?: string,
    refreshTtlMs: number = DEFAULT_REFRESH_TTL_MS,
  ) {
    const payload: JwtPayload = { sub: userId, organizationId, role, branchId };

    const accessToken = this.jwtService.sign(payload, {
      secret: this.accessSecret,
      expiresIn: '15m',
    });

    const refreshToken = crypto.randomBytes(64).toString('hex');
    const tokenHash = hashToken(refreshToken);
    const expiresAt = new Date(Date.now() + refreshTtlMs);

    // Enforce per-user token cap: delete oldest tokens beyond the limit
    const existingTokens = await this.prisma.refreshToken.findMany({
      where: { userId },
      orderBy: { createdAt: 'asc' },
      select: { id: true },
    });

    if (existingTokens.length >= MAX_REFRESH_TOKENS_PER_USER) {
      const toDelete = existingTokens
        .slice(0, existingTokens.length - MAX_REFRESH_TOKENS_PER_USER + 1)
        .map((t) => t.id);
      await this.prisma.refreshToken.deleteMany({
        where: { id: { in: toDelete } },
      });
    }

    await this.prisma.refreshToken.create({
      data: {
        userId,
        token: tokenHash,
        organizationId,
        role,
        expiresAt,
        deviceInfo,
        ipAddress,
      },
    });

    return { accessToken, refreshToken };
  }

  async generateBusinessSelectionChallenge(userId: string) {
    const selectionToken = crypto.randomBytes(48).toString('hex');
    const tokenHash = hashToken(selectionToken);
    const now = new Date();

    await this.prisma.refreshToken.deleteMany({
      where: {
        userId,
        organizationId: BUSINESS_SELECTION_ORG_ID,
        expiresAt: { lt: now },
      },
    });

    await this.prisma.refreshToken.create({
      data: {
        userId,
        token: tokenHash,
        organizationId: BUSINESS_SELECTION_ORG_ID,
        role: BUSINESS_SELECTION_ROLE,
        expiresAt: new Date(now.getTime() + BUSINESS_SELECTION_TTL_MS),
      },
    });

    return selectionToken;
  }

  async consumeBusinessSelectionChallenge(selectionToken: string) {
    if (!selectionToken || selectionToken.trim().length === 0) {
      throw new UnauthorizedException(
        'Business selection session is missing or invalid. Please log in again.',
      );
    }

    const tokenHash = hashToken(selectionToken);
    const challenge = await this.prisma.refreshToken.findUnique({
      where: { token: tokenHash },
    });

    if (
      !challenge ||
      challenge.organizationId !== BUSINESS_SELECTION_ORG_ID ||
      challenge.role !== BUSINESS_SELECTION_ROLE
    ) {
      throw new UnauthorizedException(
        'Business selection session is invalid. Please log in again.',
      );
    }

    if (challenge.expiresAt < new Date()) {
      await this.prisma.refreshToken.deleteMany({
        where: { id: challenge.id },
      });
      throw new UnauthorizedException(
        'Business selection session expired. Please log in again.',
      );
    }

    const consumed = await this.prisma.refreshToken.deleteMany({
      where: {
        id: challenge.id,
        token: tokenHash,
        organizationId: BUSINESS_SELECTION_ORG_ID,
        role: BUSINESS_SELECTION_ROLE,
      },
    });

    if (consumed.count !== 1) {
      throw new UnauthorizedException(
        'Business selection session was already used. Please log in again.',
      );
    }

    return challenge.userId;
  }

  private async findRefreshToken(tokenHash: string) {
    for (let attempt = 0; attempt < 3; attempt += 1) {
      try {
        return await this.prisma.refreshToken.findUnique({
          where: { token: tokenHash },
          include: {
            user: {
              include: { userAssignments: true },
            },
          },
        });
      } catch (error) {
        if (!this.isTransientDbError(error) || attempt === 2) throw error;
        await new Promise((resolve) =>
          setTimeout(resolve, 300 * (attempt + 1)),
        );
      }
    }
    return null;
  }

  private isTransientDbError(error: unknown): boolean {
    const code = (error as { code?: string } | null)?.code;
    return (
      code === 'ETIMEDOUT' ||
      code === 'ECONNRESET' ||
      code === 'P1001' ||
      code === 'P1008' ||
      code === 'P1017'
    );
  }

  async refreshTokens(
    refreshToken: string,
    deviceInfo?: string,
    ipAddress?: string,
  ) {
    const tokenHash = hashToken(refreshToken);

    const token = await this.findRefreshToken(tokenHash);

    if (!token || token.expiresAt < new Date()) {
      throw new UnauthorizedException(
        'Your session has expired. Please log in again.',
      );
    }

    if (
      token.organizationId === BUSINESS_SELECTION_ORG_ID ||
      token.role === BUSINESS_SELECTION_ROLE
    ) {
      await this.prisma.refreshToken.delete({ where: { id: token.id } });
      throw new UnauthorizedException(
        'Business selection sessions cannot be used as refresh tokens.',
      );
    }

    // Use the organizationId and role stored on the token record (set at login)
    const organizationId = token.organizationId;
    const role = token.role;

    // Verify the assignment still exists (user may have been removed from org)
    const assignment = token.user.userAssignments.find(
      (a) => a.organizationId === organizationId,
    );
    if (!assignment) {
      await this.prisma.refreshToken.delete({ where: { id: token.id } });
      throw new UnauthorizedException(
        'Your session is no longer valid. Please log in again.',
      );
    }

    // Rotate: delete old token, issue new one
    await this.prisma.refreshToken.delete({ where: { id: token.id } });

    const tokens = await this.generateTokens(
      token.userId,
      organizationId,
      role,
      assignment.branchId ?? undefined,
      deviceInfo,
      ipAddress,
      Math.max(token.expiresAt.getTime() - Date.now(), 60_000),
    );
    return {
      tokens,
      user: {
        id: token.userId,
      },
      roles: token.user.userAssignments.map((a) => ({
        businessId: a.organizationId,
        branchId: a.branchId,
        role: a.role,
      })),
    };
  }

  async logout(refreshToken: string) {
    const tokenHash = hashToken(refreshToken);
    await this.prisma.refreshToken.deleteMany({
      where: { token: tokenHash },
    });
  }

  async logoutAll(userId: string) {
    await this.prisma.refreshToken.deleteMany({ where: { userId } });
  }
}
