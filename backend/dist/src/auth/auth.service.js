"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
var AuthService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.AuthService = void 0;
const common_1 = require("@nestjs/common");
const prisma_service_1 = require("../prisma/prisma.service");
const otp_service_1 = require("../otp/otp.service");
const jwt_service_1 = require("./jwt.service");
const client_1 = require("@prisma/client");
const bcrypt = __importStar(require("bcrypt"));
let AuthService = AuthService_1 = class AuthService {
    prisma;
    otpService;
    jwtService;
    logger = new common_1.Logger(AuthService_1.name);
    saltRounds = 12;
    constructor(prisma, otpService, jwtService) {
        this.prisma = prisma;
        this.otpService = otpService;
        this.jwtService = jwtService;
    }
    async sendOtp(phone) {
        await this.otpService.generateOtp(phone);
        return { message: 'OTP sent successfully' };
    }
    async loginWithPassword(phone, password, organizationId) {
        this.logger.log(`Login attempt: phone=${phone}, organizationId=${organizationId || 'not provided'}`);
        const user = await this.prisma.user.findUnique({
            where: { phone },
            include: { userAssignments: true },
        });
        if (!user) {
            this.logger.warn(`Login failed: no user found for phone=${phone}`);
            throw new common_1.UnauthorizedException('Invalid credentials');
        }
        if (!user.passwordHash) {
            this.logger.warn(`Login failed: no password hash for user id=${user.id}`);
            throw new common_1.UnauthorizedException('Password not set. Please use OTP login or activate your invitation.');
        }
        const isPasswordValid = await bcrypt.compare(password, user.passwordHash);
        if (!isPasswordValid) {
            this.logger.warn(`Login failed: invalid password for user id=${user.id}`);
            throw new common_1.UnauthorizedException('Invalid credentials');
        }
        let assignment;
        if (organizationId) {
            assignment = user.userAssignments.find(a => a.organizationId === organizationId);
            if (!assignment) {
                throw new common_1.BadRequestException('You are not a member of this organization');
            }
        }
        else if (user.userAssignments.length === 1) {
            assignment = user.userAssignments[0];
        }
        else {
            throw new common_1.BadRequestException('Please specify which organization to log in to');
        }
        this.logger.log(`Login successful for user id=${user.id}`);
        const tokens = await this.jwtService.generateTokens(user.id, assignment.organizationId, assignment.role);
        return {
            tokens,
            user: {
                id: user.id,
                fullName: user.fullName,
                phone: user.phone,
                email: user.email,
                status: user.status,
                createdAt: user.createdAt,
                updatedAt: user.updatedAt,
            },
            roles: user.userAssignments.map(a => ({
                businessId: a.organizationId,
                branchId: a.branchId,
                role: a.role,
            })),
        };
    }
    async verifyOtpAndLogin(phone, code, organizationId) {
        await this.otpService.verifyOtp(phone, code);
        let user = await this.prisma.user.findUnique({
            where: { phone },
            include: { userAssignments: true },
        });
        if (!user) {
            if (!organizationId) {
                throw new common_1.UnauthorizedException('User not found. Please provide an organization ID or create a business account.');
            }
            const organization = await this.prisma.organization.findUnique({
                where: { id: organizationId },
            });
            if (!organization) {
                throw new common_1.BadRequestException('Organization not found');
            }
            this.logger.log(`Auto-creating CASHIER for phone=${phone} org=${organizationId}`);
            user = await this.prisma.user.create({
                data: {
                    phone,
                    userAssignments: {
                        create: {
                            organizationId,
                            role: client_1.Role.CASHIER,
                        },
                    },
                },
                include: { userAssignments: true },
            });
        }
        let assignment;
        if (organizationId) {
            assignment = user.userAssignments.find(a => a.organizationId === organizationId);
            if (!assignment) {
                throw new common_1.BadRequestException('You are not a member of this organization');
            }
        }
        else if (user.userAssignments.length === 1) {
            assignment = user.userAssignments[0];
        }
        else {
            throw new common_1.BadRequestException('Please specify which organization to log in to');
        }
        const tokens = await this.jwtService.generateTokens(user.id, assignment.organizationId, assignment.role);
        return {
            tokens,
            user: {
                id: user.id,
                fullName: user.fullName,
                phone: user.phone,
                email: user.email,
                status: user.status,
                createdAt: user.createdAt,
                updatedAt: user.updatedAt,
            },
            roles: user.userAssignments.map(a => ({
                businessId: a.organizationId,
                branchId: a.branchId,
                role: a.role,
            })),
        };
    }
    async createBusiness(name, fullName, phone, otpCode, password, email, address, type, city, country) {
        await this.otpService.verifyOtp(phone, otpCode);
        let user = await this.prisma.user.findUnique({
            where: { phone },
            include: { userAssignments: true },
        });
        if (user?.userAssignments.some(a => a.role === client_1.Role.OWNER)) {
            throw new common_1.BadRequestException('This phone number is already registered with a business');
        }
        const organization = await this.prisma.organization.create({
            data: {
                name,
                phone,
                email,
                address,
                type: type ?? 'restaurant',
                city,
                country,
            },
        });
        const startDate = new Date();
        const endDate = new Date(startDate);
        endDate.setDate(endDate.getDate() + 14);
        await this.prisma.subscription.create({
            data: {
                organizationId: organization.id,
                planName: 'free_trial',
                status: client_1.SubscriptionStatus.ACTIVE,
                startDate,
                endDate,
                maxUsers: 5,
                maxDevices: 10,
            },
        });
        const passwordHash = await bcrypt.hash(password, this.saltRounds);
        if (user) {
            user = await this.prisma.user.update({
                where: { id: user.id },
                data: {
                    fullName,
                    passwordHash,
                    email,
                    userAssignments: {
                        create: {
                            organizationId: organization.id,
                            role: client_1.Role.OWNER,
                        },
                    },
                },
                include: { userAssignments: true },
            });
        }
        else {
            user = await this.prisma.user.create({
                data: {
                    phone,
                    fullName,
                    passwordHash,
                    email,
                    userAssignments: {
                        create: {
                            organizationId: organization.id,
                            role: client_1.Role.OWNER,
                        },
                    },
                },
                include: { userAssignments: true },
            });
        }
        this.logger.log(`Business created: org=${organization.id} owner=${user.id}`);
        const tokens = await this.jwtService.generateTokens(user.id, organization.id, client_1.Role.OWNER);
        return {
            organization,
            user: {
                id: user.id,
                fullName: user.fullName,
                phone: user.phone,
                email: user.email,
                status: user.status,
                createdAt: user.createdAt,
                updatedAt: user.updatedAt,
            },
            tokens,
            roles: user.userAssignments.map(a => ({
                businessId: a.organizationId,
                branchId: a.branchId,
                role: a.role,
            })),
        };
    }
    async changePassword(userId, currentPassword, newPassword) {
        const user = await this.prisma.user.findUniqueOrThrow({
            where: { id: userId },
        });
        if (!user.passwordHash) {
            throw new common_1.BadRequestException('No password set. Use reset password instead.');
        }
        const isCurrentPasswordValid = await bcrypt.compare(currentPassword, user.passwordHash);
        if (!isCurrentPasswordValid) {
            throw new common_1.UnauthorizedException('Current password is incorrect');
        }
        const newPasswordHash = await bcrypt.hash(newPassword, this.saltRounds);
        await this.prisma.user.update({
            where: { id: userId },
            data: { passwordHash: newPasswordHash },
        });
        return { message: 'Password changed successfully' };
    }
    async resetPassword(phone, otpCode, newPassword) {
        await this.otpService.verifyOtp(phone, otpCode);
        const user = await this.prisma.user.findUnique({
            where: { phone },
        });
        if (!user) {
            throw new common_1.BadRequestException('User not found');
        }
        const newPasswordHash = await bcrypt.hash(newPassword, this.saltRounds);
        await this.prisma.user.update({
            where: { id: user.id },
            data: { passwordHash: newPasswordHash },
        });
        return { message: 'Password reset successfully' };
    }
    async getMe(userId, organizationId) {
        const user = await this.prisma.user.findUniqueOrThrow({
            where: { id: userId },
            include: { userAssignments: true },
        });
        const organization = await this.prisma.organization.findUniqueOrThrow({
            where: { id: organizationId },
        });
        return { user, organization };
    }
    async addStaff(organizationId, fullName, phone, role, branchId, password) {
        if (branchId) {
            const branch = await this.prisma.branch.findFirst({
                where: { id: branchId, organizationId },
            });
            if (!branch) {
                throw new common_1.BadRequestException('Branch not found in your organization');
            }
        }
        let user = await this.prisma.user.findUnique({
            where: { phone },
            include: { userAssignments: true },
        });
        if (user) {
            const existingAssignment = user.userAssignments.find(a => a.organizationId === organizationId);
            if (existingAssignment) {
                throw new common_1.BadRequestException('This user is already a member of your organization');
            }
            await this.prisma.userBusinessAssignment.create({
                data: {
                    userId: user.id,
                    organizationId,
                    role,
                    branchId: branchId || null,
                },
            });
            this.logger.log(`Existing user added to org: id=${user.id} role=${role} org=${organizationId}`);
            return {
                ...user,
                organizationId,
                branchId,
                role,
            };
        }
        if (password) {
            const passwordHash = await bcrypt.hash(password, this.saltRounds);
            const newUser = await this.prisma.user.create({
                data: {
                    phone,
                    fullName,
                    passwordHash,
                },
            });
            await this.prisma.userBusinessAssignment.create({
                data: {
                    userId: newUser.id,
                    organizationId,
                    role,
                    branchId: branchId || null,
                },
            });
            this.logger.log(`New user created and added to org: id=${newUser.id} role=${role} org=${organizationId}`);
            return {
                ...newUser,
                organizationId,
                branchId,
                role,
            };
        }
        const invitation = await this.prisma.invitation.create({
            data: {
                phone,
                organizationId,
                role,
                branchId: branchId || null,
            },
        });
        this.logger.log(`Invitation created: id=${invitation.id} phone=${phone} role=${role}`);
        await this.otpService.sendInvitationSms(phone, role);
        return invitation;
    }
    async getInvitation(phone) {
        const invitations = await this.prisma.invitation.findMany({
            where: { phone, status: 'PENDING' },
            include: { organization: true, branch: true },
        });
        if (invitations.length === 0) {
            throw new common_1.BadRequestException('No pending invitations found for this phone number');
        }
        return invitations;
    }
    async activateInvitation(phone, otpCode, fullName, password, organizationId) {
        await this.otpService.verifyOtp(phone, otpCode);
        const invitation = await this.prisma.invitation.findFirst({
            where: {
                phone,
                organizationId,
                status: 'PENDING',
            },
        });
        if (!invitation) {
            throw new common_1.BadRequestException('Invitation not found');
        }
        let user = await this.prisma.user.findUnique({
            where: { phone },
        });
        const passwordHash = await bcrypt.hash(password, this.saltRounds);
        if (!user) {
            user = await this.prisma.user.create({
                data: {
                    phone,
                    fullName,
                    passwordHash,
                },
            });
        }
        else {
            user = await this.prisma.user.update({
                where: { id: user.id },
                data: {
                    fullName,
                    passwordHash,
                },
            });
        }
        await this.prisma.userBusinessAssignment.create({
            data: {
                userId: user.id,
                organizationId,
                role: invitation.role,
                branchId: invitation.branchId,
            },
        });
        await this.prisma.invitation.update({
            where: { id: invitation.id },
            data: { status: 'ACTIVE' },
        });
        this.logger.log(`Invitation activated: user id=${user.id}`);
        const tokens = await this.jwtService.generateTokens(user.id, organizationId, invitation.role);
        return {
            tokens,
            user: {
                id: user.id,
                fullName: user.fullName,
                phone: user.phone,
                email: user.email,
                status: user.status,
                createdAt: user.createdAt,
                updatedAt: user.updatedAt,
            },
            roles: [
                {
                    businessId: organizationId,
                    branchId: invitation.branchId,
                    role: invitation.role,
                },
            ],
        };
    }
    async getStaff(organizationId, branchId) {
        return this.prisma.userBusinessAssignment.findMany({
            where: {
                organizationId,
                role: { not: 'OWNER' },
                ...(branchId ? { branchId } : {}),
            },
            orderBy: { createdAt: 'desc' },
            include: {
                user: true,
                branch: { select: { id: true, name: true } },
            },
        });
    }
    async removeStaff(staffAssignmentId, organizationId) {
        const assignment = await this.prisma.userBusinessAssignment.findFirst({
            where: { id: staffAssignmentId, organizationId },
        });
        if (!assignment) {
            throw new common_1.BadRequestException('Staff member not found in your organization');
        }
        if (assignment.role === client_1.Role.OWNER) {
            throw new common_1.BadRequestException('Cannot remove the organization owner');
        }
        await this.prisma.userBusinessAssignment.delete({ where: { id: staffAssignmentId } });
        return { message: 'Staff member removed successfully' };
    }
};
exports.AuthService = AuthService;
exports.AuthService = AuthService = AuthService_1 = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService,
        otp_service_1.OtpService,
        jwt_service_1.JwtService])
], AuthService);
//# sourceMappingURL=auth.service.js.map