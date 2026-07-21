"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
var PaymentAccountService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.PaymentAccountService = void 0;
const common_1 = require("@nestjs/common");
const prisma_service_1 = require("../prisma/prisma.service");
const client_1 = require("@prisma/client");
let PaymentAccountService = PaymentAccountService_1 = class PaymentAccountService {
    prisma;
    logger = new common_1.Logger(PaymentAccountService_1.name);
    constructor(prisma) {
        this.prisma = prisma;
    }
    async create(organizationId, dto) {
        this.logger.log(`[create] Creating payment account for org: ${organizationId}, provider: ${dto.provider}`);
        if (dto.provider === client_1.PaymentProvider.CBE) {
            if (!dto.suffix || dto.suffix.length !== 8) {
                throw new common_1.BadRequestException('CBE payment account requires an 8-digit suffix');
            }
        }
        if (dto.provider === client_1.PaymentProvider.ABYSSINIA) {
            if (!dto.suffix || dto.suffix.length !== 5) {
                throw new common_1.BadRequestException('Abyssinia payment account requires a 5-digit suffix');
            }
        }
        try {
            const account = await this.prisma.paymentAccount.upsert({
                where: {
                    organizationId_provider_branchId: {
                        organizationId,
                        provider: dto.provider,
                        branchId: dto.branchId || null,
                    },
                },
                update: {
                    accountNumber: dto.accountNumber,
                    suffix: dto.suffix,
                    accountHolderName: dto.accountHolderName,
                    isActive: true,
                },
                create: {
                    organizationId,
                    provider: dto.provider,
                    accountNumber: dto.accountNumber,
                    suffix: dto.suffix,
                    accountHolderName: dto.accountHolderName,
                    branchId: dto.branchId || null,
                },
            });
            this.logger.log(`[create] Payment account created/updated: ${account.id}`);
            return account;
        }
        catch (err) {
            this.logger.error(`[create] DB error: ${err?.message ?? String(err)}`);
            throw new common_1.BadRequestException('Failed to create payment account');
        }
    }
    async findAll(organizationId) {
        return this.prisma.paymentAccount.findMany({
            where: { organizationId },
            orderBy: { createdAt: 'desc' },
            include: {
                branch: true,
            },
        });
    }
    async findByOrganizationAndBranch(organizationId, branchId) {
        return this.prisma.paymentAccount.findMany({
            where: {
                organizationId,
                branchId: branchId ?? undefined,
                isActive: true,
            },
            include: {
                branch: true,
            },
        });
    }
    async findByProviderAndBranch(organizationId, provider, branchId) {
        const account = await this.prisma.paymentAccount.findFirst({
            where: {
                organizationId,
                provider,
                branchId: branchId ?? undefined,
                isActive: true,
            },
        });
        if (!account) {
            throw new common_1.NotFoundException(`Payment account for ${provider} not found`);
        }
        return account;
    }
    async update(organizationId, provider, branchId, dto) {
        this.logger.log(`[update] Updating payment account for org: ${organizationId}, provider: ${provider}`);
        if (provider === client_1.PaymentProvider.CBE && dto.suffix) {
            if (dto.suffix.length !== 8) {
                throw new common_1.BadRequestException('CBE payment account requires an 8-digit suffix');
            }
        }
        if (provider === client_1.PaymentProvider.ABYSSINIA && dto.suffix) {
            if (dto.suffix.length !== 5) {
                throw new common_1.BadRequestException('Abyssinia payment account requires a 5-digit suffix');
            }
        }
        const account = await this.prisma.paymentAccount.updateMany({
            where: {
                organizationId,
                provider,
                branchId: branchId ?? undefined,
            },
            data: dto,
        });
        if (account.count === 0) {
            throw new common_1.NotFoundException(`Payment account for ${provider} not found`);
        }
        const updatedAccount = await this.prisma.paymentAccount.findFirst({
            where: {
                organizationId,
                provider,
                branchId: branchId ?? undefined,
            },
        });
        this.logger.log(`[update] Payment account updated: ${updatedAccount.id}`);
        return updatedAccount;
    }
    async remove(organizationId, provider, branchId) {
        this.logger.log(`[remove] Deleting payment account for org: ${organizationId}, provider: ${provider}`);
        const deleted = await this.prisma.paymentAccount.deleteMany({
            where: {
                organizationId,
                provider,
                branchId: branchId ?? undefined,
            },
        });
        if (deleted.count === 0) {
            throw new common_1.NotFoundException(`Payment account for ${provider} not found`);
        }
        return { message: 'Payment account deleted successfully' };
    }
};
exports.PaymentAccountService = PaymentAccountService;
exports.PaymentAccountService = PaymentAccountService = PaymentAccountService_1 = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService])
], PaymentAccountService);
//# sourceMappingURL=payment-account.service.js.map