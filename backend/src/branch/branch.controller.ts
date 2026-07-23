import {
  Controller,
  Get,
  Post,
  Body,
  Patch,
  Param,
  Delete,
  UseGuards,
  Request,
} from '@nestjs/common';
import { BranchService } from './branch.service';
import { CreateBranchDto } from './dto/create-branch.dto';
import { JwtAuthGuard, JwtPayload } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { BranchGuard } from '../auth/guards/branch.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { Role } from '@prisma/client';

@Controller('branches')
@UseGuards(JwtAuthGuard, RolesGuard, BranchGuard)
export class BranchController {
  constructor(private readonly branchService: BranchService) {}

  @Post()
  @Roles(Role.OWNER)
  create(
    @Request() req: { user: JwtPayload },
    @Body() createBranchDto: CreateBranchDto,
  ) {
    return this.branchService.create(req.user.organizationId, createBranchDto);
  }

  @Get()
  findAll(@Request() req: { user: JwtPayload; branchFilter?: string }) {
    return this.branchService.findAll(
      req.user.organizationId,
      req.branchFilter,
    );
  }

  @Get(':id')
  findOne(@Request() req: { user: JwtPayload }, @Param('id') id: string) {
    return this.branchService.findOne(id, req.user.organizationId);
  }

  @Patch(':id')
  @Roles(Role.OWNER)
  update(
    @Request() req: { user: JwtPayload },
    @Param('id') id: string,
    @Body() updateBranchDto: CreateBranchDto,
  ) {
    return this.branchService.update(
      id,
      req.user.organizationId,
      updateBranchDto,
    );
  }

  @Delete(':id')
  @Roles(Role.OWNER)
  remove(@Request() req: { user: JwtPayload }, @Param('id') id: string) {
    return this.branchService.remove(id, req.user.organizationId);
  }
}
