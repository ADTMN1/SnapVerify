import { BranchService } from './branch.service';
import { CreateBranchDto } from './dto/create-branch.dto';
import { JwtPayload } from '../auth/guards/jwt-auth.guard';
export declare class BranchController {
    private readonly branchService;
    constructor(branchService: BranchService);
    create(req: {
        user: JwtPayload;
    }, createBranchDto: CreateBranchDto): Promise<{
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
    findAll(req: {
        user: JwtPayload;
        branchFilter?: string;
    }): Promise<{
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
    findOne(req: {
        user: JwtPayload;
    }, id: string): Promise<{
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
    update(req: {
        user: JwtPayload;
    }, id: string, updateBranchDto: CreateBranchDto): Promise<import("@prisma/client").Prisma.BatchPayload>;
    remove(req: {
        user: JwtPayload;
    }, id: string): Promise<import("@prisma/client").Prisma.BatchPayload>;
}
