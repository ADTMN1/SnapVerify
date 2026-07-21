import { PrismaService } from '../prisma/prisma.service';
import { OtpService } from '../otp/otp.service';
import { JwtService } from './jwt.service';
import { Role } from '@prisma/client';
export declare class AuthService {
    private prisma;
    private otpService;
    private jwtService;
    private readonly logger;
    private readonly saltRounds;
    constructor(prisma: PrismaService, otpService: OtpService, jwtService: JwtService);
    sendOtp(phone: string): Promise<{
        message: string;
    }>;
    loginWithPassword(phone: string, password: string, organizationId?: string): Promise<{
        tokens: {
            accessToken: string;
            refreshToken: string;
        };
        user: {
            id: string;
            fullName: string | null;
            phone: string;
            email: string | null;
            status: string;
            createdAt: Date;
            updatedAt: Date;
        };
        roles: {
            businessId: string;
            branchId: string | null;
            role: import("@prisma/client").$Enums.Role;
        }[];
    }>;
    verifyOtpAndLogin(phone: string, code: string, organizationId?: string): Promise<{
        tokens: {
            accessToken: string;
            refreshToken: string;
        };
        user: {
            id: string;
            fullName: string | null;
            phone: string;
            email: string | null;
            status: string;
            createdAt: Date;
            updatedAt: Date;
        };
        roles: {
            businessId: string;
            branchId: string | null;
            role: import("@prisma/client").$Enums.Role;
        }[];
    }>;
    createBusiness(name: string, fullName: string | undefined, phone: string, otpCode: string, password: string, email?: string, address?: string, type?: string, city?: string, country?: string): Promise<{
        organization: {
            phone: string;
            id: string;
            createdAt: Date;
            name: string;
            email: string | null;
            status: string;
            updatedAt: Date;
            type: string;
            address: string | null;
            city: string | null;
            country: string | null;
            logoUrl: string | null;
            subscriptionPlan: string | null;
        };
        user: {
            id: string;
            fullName: string | null;
            phone: string;
            email: string | null;
            status: string;
            createdAt: Date;
            updatedAt: Date;
        };
        tokens: {
            accessToken: string;
            refreshToken: string;
        };
        roles: {
            businessId: string;
            branchId: string | null;
            role: import("@prisma/client").$Enums.Role;
        }[];
    }>;
    changePassword(userId: string, currentPassword: string, newPassword: string): Promise<{
        message: string;
    }>;
    resetPassword(phone: string, otpCode: string, newPassword: string): Promise<{
        message: string;
    }>;
    getMe(userId: string, organizationId: string): Promise<{
        user: {
            userAssignments: {
                id: string;
                createdAt: Date;
                userId: string;
                status: string;
                updatedAt: Date;
                organizationId: string;
                branchId: string | null;
                role: import("@prisma/client").$Enums.Role;
            }[];
        } & {
            phone: string;
            id: string;
            createdAt: Date;
            fullName: string | null;
            email: string | null;
            passwordHash: string | null;
            status: string;
            updatedAt: Date;
        };
        organization: {
            phone: string;
            id: string;
            createdAt: Date;
            name: string;
            email: string | null;
            status: string;
            updatedAt: Date;
            type: string;
            address: string | null;
            city: string | null;
            country: string | null;
            logoUrl: string | null;
            subscriptionPlan: string | null;
        };
    }>;
    addStaff(organizationId: string, fullName: string, phone: string, role: Role, branchId?: string, password?: string): Promise<{
        phone: string;
        id: string;
        createdAt: Date;
        status: string;
        updatedAt: Date;
        organizationId: string;
        branchId: string | null;
        role: import("@prisma/client").$Enums.Role;
    } | {
        organizationId: string;
        branchId: string | undefined;
        role: import("@prisma/client").$Enums.Role;
        userAssignments: {
            id: string;
            createdAt: Date;
            userId: string;
            status: string;
            updatedAt: Date;
            organizationId: string;
            branchId: string | null;
            role: import("@prisma/client").$Enums.Role;
        }[];
        phone: string;
        id: string;
        createdAt: Date;
        fullName: string | null;
        email: string | null;
        passwordHash: string | null;
        status: string;
        updatedAt: Date;
    } | {
        organizationId: string;
        branchId: string | undefined;
        role: import("@prisma/client").$Enums.Role;
        phone: string;
        id: string;
        createdAt: Date;
        fullName: string | null;
        email: string | null;
        passwordHash: string | null;
        status: string;
        updatedAt: Date;
    }>;
    getInvitation(phone: string): Promise<({
        branch: {
            phone: string | null;
            id: string;
            createdAt: Date;
            name: string;
            updatedAt: Date;
            organizationId: string;
            address: string | null;
            latitude: import("@prisma/client-runtime-utils").Decimal | null;
            longitude: import("@prisma/client-runtime-utils").Decimal | null;
        } | null;
        organization: {
            phone: string;
            id: string;
            createdAt: Date;
            name: string;
            email: string | null;
            status: string;
            updatedAt: Date;
            type: string;
            address: string | null;
            city: string | null;
            country: string | null;
            logoUrl: string | null;
            subscriptionPlan: string | null;
        };
    } & {
        phone: string;
        id: string;
        createdAt: Date;
        status: string;
        updatedAt: Date;
        organizationId: string;
        branchId: string | null;
        role: import("@prisma/client").$Enums.Role;
    })[]>;
    activateInvitation(phone: string, otpCode: string, fullName: string, password: string, organizationId: string): Promise<{
        tokens: {
            accessToken: string;
            refreshToken: string;
        };
        user: {
            id: string;
            fullName: string | null;
            phone: string;
            email: string | null;
            status: string;
            createdAt: Date;
            updatedAt: Date;
        };
        roles: {
            businessId: string;
            branchId: string | null;
            role: import("@prisma/client").$Enums.Role;
        }[];
    }>;
    getStaff(organizationId: string, branchId?: string): Promise<({
        branch: {
            id: string;
            name: string;
        } | null;
        user: {
            phone: string;
            id: string;
            createdAt: Date;
            fullName: string | null;
            email: string | null;
            passwordHash: string | null;
            status: string;
            updatedAt: Date;
        };
    } & {
        id: string;
        createdAt: Date;
        userId: string;
        status: string;
        updatedAt: Date;
        organizationId: string;
        branchId: string | null;
        role: import("@prisma/client").$Enums.Role;
    })[]>;
    removeStaff(staffAssignmentId: string, organizationId: string): Promise<{
        message: string;
    }>;
}
