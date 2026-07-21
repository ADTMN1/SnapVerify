import { PrismaService } from '../prisma/prisma.service';
import { CreateBranchDto } from './dto/create-branch.dto';
export declare class BranchService {
    private prisma;
    constructor(prisma: PrismaService);
    create(organizationId: string, createBranchDto: CreateBranchDto): Promise<{
        phone: string | null;
        id: string;
        createdAt: Date;
        name: string;
        updatedAt: Date;
        organizationId: string;
        address: string | null;
        latitude: import("@prisma/client-runtime-utils").Decimal | null;
        longitude: import("@prisma/client-runtime-utils").Decimal | null;
    }>;
    findAll(organizationId: string, branchId?: string): Promise<{
        phone: string | null;
        id: string;
        createdAt: Date;
        name: string;
        updatedAt: Date;
        organizationId: string;
        address: string | null;
        latitude: import("@prisma/client-runtime-utils").Decimal | null;
        longitude: import("@prisma/client-runtime-utils").Decimal | null;
    }[]>;
    findOne(id: string, organizationId: string): Promise<{
        phone: string | null;
        id: string;
        createdAt: Date;
        name: string;
        updatedAt: Date;
        organizationId: string;
        address: string | null;
        latitude: import("@prisma/client-runtime-utils").Decimal | null;
        longitude: import("@prisma/client-runtime-utils").Decimal | null;
    } | null>;
    update(id: string, organizationId: string, updateBranchDto: CreateBranchDto): Promise<import("@prisma/client").Prisma.BatchPayload>;
    remove(id: string, organizationId: string): Promise<import("@prisma/client").Prisma.BatchPayload>;
}
