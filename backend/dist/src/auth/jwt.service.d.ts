import { JwtService as NestJwtService } from '@nestjs/jwt';
import { PrismaService } from '../prisma/prisma.service';
export declare class JwtService {
    private jwtService;
    private prisma;
    constructor(jwtService: NestJwtService, prisma: PrismaService);
    generateTokens(userId: string, organizationId: string, role: string, branchId?: string, deviceInfo?: string, ipAddress?: string): Promise<{
        accessToken: string;
        refreshToken: string;
    }>;
    refreshTokens(refreshToken: string, deviceInfo?: string, ipAddress?: string): Promise<{
        tokens: {
            accessToken: string;
            refreshToken: string;
        };
        user: {
            id: string;
        };
        roles: {
            businessId: string;
            branchId: string | null;
            role: import("@prisma/client").$Enums.Role;
        }[];
    }>;
    logout(refreshToken: string): Promise<void>;
}
