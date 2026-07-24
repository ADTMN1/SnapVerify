import { Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService as NestJwtService } from '@nestjs/jwt';
import { PrismaService } from '../prisma/prisma.service';
import * as crypto from 'crypto';

interface JwtPayload {
  sub: string;
  organizationId: string;
  role: string;
  branchId?: string;
}

const MAX_REFRESH_TOKENS_PER_USER = 10;

function hashToken(token: string): string {
  return crypto.createHash('sha256').update(token).digest('hex');
}

@Injectable()
export class JwtService {
  constructor(
    private jwtService: NestJwtService,
    private prisma: PrismaService,
  ) {}

  async generateTokens(
    userId: string,
    organizationId: string,
    role: string,
    branchId?: string,
    deviceInfo?: string,
    ipAddress?: string,
  ) {
    const payload: JwtPayload = { sub: userId, organizationId, role, branchId };

    const accessToken = this.jwtService.sign(payload, {
      secret: process.env.JWT_ACCESS_SECRET,
      expiresIn: '15m',
    });

    const refreshToken = crypto.randomBytes(64).toString('hex');
    const tokenHash = hashToken(refreshToken);
    const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);

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

  async refreshTokens(
    refreshToken: string,
    deviceInfo?: string,
    ipAddress?: string,
  ) {
    const tokenHash = hashToken(refreshToken);

    const token = await this.prisma.refreshToken.findUnique({
      where: { token: tokenHash },
      include: {
        user: {
          include: { userAssignments: true },
        },
      },
    });

    if (!token || token.expiresAt < new Date()) {
      throw new UnauthorizedException('Invalid refresh token');
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
      throw new UnauthorizedException('Organization assignment no longer valid');
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
