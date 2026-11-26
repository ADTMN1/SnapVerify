import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService as NestJwtService } from '@nestjs/jwt';
import { resolveAdminAuthSecrets } from '../../config/admin-auth-secrets';
import { PrismaService } from '../../prisma/prisma.service';
import * as crypto from 'crypto';

interface AdminJwtPayload {
  sub: string;
  email: string;
  role: string;
}

const MAX_REFRESH_TOKENS_PER_ADMIN = 10;

/** Initial refresh lifetime; preserved across rotations gives an absolute session lifetime. */
export const ADMIN_REFRESH_TTL_MS = 7 * 24 * 60 * 60 * 1000;

export function resolveAdminRole(user: {
  isPlatformAdmin?: boolean | null;
  userAssignments: Array<{ role: string; status?: string }>;
}): string {
  if (user.isPlatformAdmin === true) return 'SUPER_ADMIN';
  const isOwner = user.userAssignments.some(
    (assignment) =>
      assignment.role === 'OWNER' && assignment.status !== 'inactive',
  );
  if (isOwner) return 'BUSINESS_OWNER';
  throw new UnauthorizedException('You no longer have admin access');
}

function hashAdminRefreshToken(token: string, refreshSecret: string): string {
  return crypto.createHmac('sha256', refreshSecret).update(token).digest('hex');
}

@Injectable()
export class AdminJwtService {
  private readonly accessSecret: string;
  private readonly refreshSecret: string;

  constructor(
    private jwtService: NestJwtService,
    config: ConfigService,
    private prisma: PrismaService,
  ) {
    const secrets = resolveAdminAuthSecrets(config);
    this.accessSecret = secrets.accessSecret;
    this.refreshSecret = secrets.refreshSecret;
  }

  async generateTokens(
    userId: string,
    email: string,
    role: string,
    ipAddress?: string,
    userAgent?: string,
    refreshTtlMs: number = ADMIN_REFRESH_TTL_MS,
  ) {
    const payload: AdminJwtPayload = { sub: userId, email, role };

    const accessToken = this.jwtService.sign(payload, {
      secret: this.accessSecret,
      expiresIn: '15m',
    });

    const refreshToken = crypto.randomBytes(64).toString('hex');
    const tokenHash = hashAdminRefreshToken(refreshToken, this.refreshSecret);
    const expiresAt = new Date(
      Date.now() + Math.min(refreshTtlMs, ADMIN_REFRESH_TTL_MS),
    );

    // Enforce per-admin token cap
    const existingTokens = await this.prisma.refreshToken.findMany({
      where: { userId },
      orderBy: { createdAt: 'asc' },
      select: { id: true },
    });

    if (existingTokens.length >= MAX_REFRESH_TOKENS_PER_ADMIN) {
      const toDelete = existingTokens
        .slice(0, existingTokens.length - MAX_REFRESH_TOKENS_PER_ADMIN + 1)
        .map((t) => t.id);
      await this.prisma.refreshToken.deleteMany({
        where: { id: { in: toDelete } },
      });
    }

    await this.prisma.refreshToken.create({
      data: {
        userId,
        token: tokenHash,
        organizationId: 'admin', // Use 'admin' as a marker for admin tokens
        role,
        expiresAt,
        deviceInfo: userAgent,
        ipAddress,
      },
    });

    return { accessToken, refreshToken };
  }

  async refreshTokens(
    refreshToken: string,
    ipAddress?: string,
    userAgent?: string,
  ) {
    const tokenHash = hashAdminRefreshToken(refreshToken, this.refreshSecret);

    const token = await this.prisma.refreshToken.findUnique({
      where: { token: tokenHash },
      include: {
        user: {
          include: { userAssignments: true },
        },
      },
    });

    if (
      !token ||
      token.expiresAt < new Date() ||
      token.organizationId !== 'admin'
    ) {
      throw new UnauthorizedException('Invalid refresh token');
    }

    const user = token.user;
    if (user.status !== 'active') {
      await this.prisma.refreshToken.delete({ where: { id: token.id } });
      throw new UnauthorizedException('Admin account is inactive');
    }

    // Re-authorise on every refresh: a demoted admin must not be able to
    // rotate a previously issued token into a still-valid session.
    let role: string;
    try {
      role = resolveAdminRole(user);
    } catch (error) {
      await this.prisma.refreshToken.delete({ where: { id: token.id } });
      throw error;
    }

    // Rotate: delete the old token and preserve the *remaining* lifetime.
    // The session therefore cannot outlive the original absolute expiry.
    const remainingMs = token.expiresAt.getTime() - Date.now();
    await this.prisma.refreshToken.delete({ where: { id: token.id } });

    return this.generateTokens(
      user.id,
      user.email || '',
      role,
      ipAddress,
      userAgent,
      Math.max(remainingMs, 60_000),
    );
  }

  async revokeToken(refreshToken: string) {
    const tokenHash = hashAdminRefreshToken(refreshToken, this.refreshSecret);
    await this.prisma.refreshToken.deleteMany({
      where: { token: tokenHash, organizationId: 'admin' },
    });
  }

  async revokeAllTokens(userId: string) {
    await this.prisma.refreshToken.deleteMany({
      where: { userId, organizationId: 'admin' },
    });
  }

  verifyAccessToken(token: string) {
    try {
      return this.jwtService.verify<AdminJwtPayload>(token, {
        secret: this.accessSecret,
      });
    } catch {
      throw new UnauthorizedException('Invalid or expired token');
    }
  }
}
