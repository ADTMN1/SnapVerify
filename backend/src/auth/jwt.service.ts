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
    const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);

    await this.prisma.refreshToken.create({
      data: {
        userId,
        token: refreshToken,
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
    const token = await this.prisma.refreshToken.findUnique({
      where: { token: refreshToken },
      include: {
        user: {
          include: { userAssignments: true },
        },
      },
    });

    if (!token || token.expiresAt < new Date()) {
      throw new UnauthorizedException('Invalid refresh token');
    }

    if (token.user.userAssignments.length === 0) {
      throw new UnauthorizedException('No organization assigned to user');
    }

    // Use the first assignment for simplicity (or we could store userAssignmentId in RefreshToken)
    const assignment = token.user.userAssignments[0];

    await this.prisma.refreshToken.delete({ where: { id: token.id } });

    const tokens = await this.generateTokens(
      token.userId,
      assignment.organizationId,
      assignment.role,
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
    await this.prisma.refreshToken.deleteMany({
      where: { token: refreshToken },
    });
  }
}
