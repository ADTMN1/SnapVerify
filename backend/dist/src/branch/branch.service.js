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
Object.defineProperty(exports, "__esModule", { value: true });
exports.BranchService = void 0;
const common_1 = require("@nestjs/common");
const prisma_service_1 = require("../prisma/prisma.service");
let BranchService = class BranchService {
    prisma;
    constructor(prisma) {
        this.prisma = prisma;
    }
    async create(organizationId, createBranchDto) {
        return this.prisma.branch.create({
            data: {
                organizationId,
                name: createBranchDto.name,
                address: createBranchDto.address,
                phone: createBranchDto.phone,
            },
        });
    }
    async findAll(organizationId, branchId) {
        return this.prisma.branch.findMany({
            where: {
                organizationId,
                ...(branchId ? { id: branchId } : {}),
            },
            orderBy: { createdAt: 'desc' },
        });
    }
    async findOne(id, organizationId) {
        return this.prisma.branch.findFirst({
            where: { id, organizationId },
        });
    }
    async update(id, organizationId, updateBranchDto) {
        return this.prisma.branch.updateMany({
            where: { id, organizationId },
            data: {
                name: updateBranchDto.name,
                address: updateBranchDto.address,
                phone: updateBranchDto.phone,
            },
        });
    }
    async remove(id, organizationId) {
        return this.prisma.branch.deleteMany({
            where: { id, organizationId },
        });
    }
};
exports.BranchService = BranchService;
exports.BranchService = BranchService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService])
], BranchService);
//# sourceMappingURL=branch.service.js.map