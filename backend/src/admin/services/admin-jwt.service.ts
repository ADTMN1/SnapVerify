import { Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService as NestJwtService } from '@nestjs/jwt';
import { PrismaService } from '../../prisma/prisma.service';
import * as crypto from 'crypto';
import { Role } from '@prisma/client';

interface AdminJwtPayload {
  sub: string;
  email: string;
  role: string;
}

const MAX_REFRESH_TOKENS_PER_ADMIN = 10;

function hashToken(token: string): string {
  return crypto.createHash('sha256').update(token).digest('hex');
}

@Injectable()
export class AdminJwtService {
  constructor(
    private jwtService: NestJwtService,
    private prisma: PrismaService,
  ) {}

  async generateTokens(
    userId: string,
    email: string,
    role: string,
    ipAddress?: string,
    userAgent?: string,
  ) {
    const payload: AdminJwtPayload = { sub: userId, email, role };

    const accessToken = this.jwtService.sign(payload, {
      secret: process.env.JWT_ADMIN_ACCESS_SECRET || process.env.JWT_ACCESS_SECRET,
      expiresIn: '15m',
    });

    const refreshToken = crypto.randomBytes(64).toString('hex');
    const tokenHash = hashToken(refreshToken);
    const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);

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
    const tokenHash = hashToken(refreshToken);

    const token = await this.prisma.refreshToken.findUnique({
      where: { token: tokenHash },
      include: {
        user: true,
      },
    });

    if (!token || token.expiresAt < new Date() || token.organizationId !== 'admin') {
      throw new UnauthorizedException('Invalid refresh token');
    }

    const user = token.user;
    if (user.status !== 'active') {
      throw new UnauthorizedException('Admin account is inactive');
    }

    // Delete old token and create new pair
    await this.prisma.refreshToken.delete({ where: { id: token.id } });

    return this.generateTokens(user.id, user.email || '', token.role, ipAddress, userAgent);
  }

  async revokeToken(refreshToken: string) {
    const tokenHash = hashToken(refreshToken);
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
        secret: process.env.JWT_ADMIN_ACCESS_SECRET || process.env.JWT_ACCESS_SECRET,
      });
    } catch {
      throw new UnauthorizedException('Invalid or expired token');
    }
  }
}
