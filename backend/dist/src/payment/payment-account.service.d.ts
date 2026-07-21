import { PrismaService } from '../prisma/prisma.service';
import { CreatePaymentAccountDto } from './dto/create-payment-account.dto';
import { UpdatePaymentAccountDto } from './dto/update-payment-account.dto';
import { PaymentProvider } from '@prisma/client';
export declare class PaymentAccountService {
    private prisma;
    private readonly logger;
    constructor(prisma: PrismaService);
    create(organizationId: string, dto: CreatePaymentAccountDto): Promise<{
        id: string;
        createdAt: Date;
        updatedAt: Date;
        organizationId: string;
        branchId: string | null;
        provider: import("@prisma/client").$Enums.PaymentProvider;
        accountNumber: string | null;
        suffix: string | null;
        accountHolderName: string | null;
        isActive: boolean;
    }>;
    findAll(organizationId: string): Promise<({
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
    } & {
        id: string;
        createdAt: Date;
        updatedAt: Date;
        organizationId: string;
        branchId: string | null;
        provider: import("@prisma/client").$Enums.PaymentProvider;
        accountNumber: string | null;
        suffix: string | null;
        accountHolderName: string | null;
        isActive: boolean;
    })[]>;
    findByOrganizationAndBranch(organizationId: string, branchId?: string): Promise<({
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
    } & {
        id: string;
        createdAt: Date;
        updatedAt: Date;
        organizationId: string;
        branchId: string | null;
        provider: import("@prisma/client").$Enums.PaymentProvider;
        accountNumber: string | null;
        suffix: string | null;
        accountHolderName: string | null;
        isActive: boolean;
    })[]>;
    findByProviderAndBranch(organizationId: string, provider: PaymentProvider, branchId?: string): Promise<{
        id: string;
        createdAt: Date;
        updatedAt: Date;
        organizationId: string;
        branchId: string | null;
        provider: import("@prisma/client").$Enums.PaymentProvider;
        accountNumber: string | null;
        suffix: string | null;
        accountHolderName: string | null;
        isActive: boolean;
    }>;
    update(organizationId: string, provider: PaymentProvider, branchId: string | undefined, dto: UpdatePaymentAccountDto): Promise<{
        id: string;
        createdAt: Date;
        updatedAt: Date;
        organizationId: string;
        branchId: string | null;
        provider: import("@prisma/client").$Enums.PaymentProvider;
        accountNumber: string | null;
        suffix: string | null;
        accountHolderName: string | null;
        isActive: boolean;
    }>;
    remove(organizationId: string, provider: PaymentProvider, branchId?: string): Promise<{
        message: string;
    }>;
}
