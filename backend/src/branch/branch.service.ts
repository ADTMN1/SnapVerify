import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateBranchDto } from './dto/create-branch.dto';

@Injectable()
export class BranchService {
  constructor(private prisma: PrismaService) {}

  async create(organizationId: string, createBranchDto: CreateBranchDto) {
    return this.prisma.branch.create({
      data: {
        organizationId,
        name: createBranchDto.name,
        address: createBranchDto.address,
        phone: createBranchDto.phone,
      },
    });
  }

  async findAll(organizationId: string, branchId?: string) {
    return this.prisma.branch.findMany({
      where: {
        organizationId,
        ...(branchId ? { id: branchId } : {}),
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  async findOne(id: string, organizationId: string) {
    return this.prisma.branch.findFirst({
      where: { id, organizationId },
    });
  }

  async update(
    id: string,
    organizationId: string,
    updateBranchDto: CreateBranchDto,
  ) {
    return this.prisma.branch.updateMany({
      where: { id, organizationId },
      data: {
        name: updateBranchDto.name,
        address: updateBranchDto.address,
        phone: updateBranchDto.phone,
      },
    });
  }

  async remove(id: string, organizationId: string) {
    return this.prisma.branch.deleteMany({
      where: { id, organizationId },
    });
  }
}
