import { AuthService } from './auth.service';
import { JwtService } from './jwt.service';
import { JwtPayload } from './guards/jwt-auth.guard';
import { SendOtpDto } from './dto/send-otp.dto';
import { VerifyOtpDto } from './dto/verify-otp.dto';
import { CreateBusinessDto } from './dto/create-business.dto';
import { RefreshTokenDto } from './dto/refresh-token.dto';
import { LoginDto } from './dto/login.dto';
import { ChangePasswordDto, ResetPasswordDto } from './dto/change-password.dto';
import { AddStaffDto } from './dto/add-staff.dto';
export declare class AuthController {
    private authService;
    private jwtService;
    constructor(authService: AuthService, jwtService: JwtService);
    sendOtp(dto: SendOtpDto): Promise<{
        message: string;
    }>;
    login(dto: LoginDto): Promise<{
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
    verifyOtp(dto: VerifyOtpDto, ipAddress: string): Promise<{
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
    createBusiness(dto: CreateBusinessDto): Promise<{
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
    refreshToken(dto: RefreshTokenDto, ipAddress: string): Promise<{
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
    logout(dto: RefreshTokenDto): Promise<{
        message: string;
    }>;
    changePassword(dto: ChangePasswordDto, req: {
        user: JwtPayload;
    }): Promise<{
        message: string;
    }>;
    resetPassword(dto: ResetPasswordDto): Promise<{
        message: string;
    }>;
    getMe(req: {
        user: JwtPayload;
    }): Promise<{
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
    addStaff(req: {
        user: JwtPayload;
    }, dto: AddStaffDto): Promise<{
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
    getStaff(req: {
        user: JwtPayload;
        branchFilter?: string;
    }): Promise<({
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
    removeStaff(req: {
        user: JwtPayload;
    }, id: string): Promise<{
        message: string;
    }>;
    getInvitations(phone: string): Promise<({
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
    activateInvitation(body: {
        phone: string;
        otpCode: string;
        fullName: string;
        password: string;
        organizationId: string;
    }): Promise<{
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
}
