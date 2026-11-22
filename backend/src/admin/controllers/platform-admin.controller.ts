import {
  Controller,
  Get,
  Patch,
  Param,
  Body,
  Query,
  UseGuards,
  HttpCode,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { PlatformAdminService } from '../services/platform-admin.service';
import { AdminJwtAuthGuard } from '../guards/admin-jwt-auth.guard';
import { AdminRolesGuard } from '../guards/admin-roles.guard';
import { AdminRoles } from '../decorators/admin-roles.decorator';
import {
  UpdatePlatformOrganizationDto,
  UpdatePlatformUserDto,
} from '../dto/platform-admin.dto';

/**
 * Platform super-admin endpoints. Every route here is restricted to users whose
 * admin token role is SUPER_ADMIN and operates across ALL organizations.
 */
@Controller('api/admin/platform')
@UseGuards(AdminJwtAuthGuard, AdminRolesGuard)
@AdminRoles('SUPER_ADMIN')
export class PlatformAdminController {
  private readonly logger = new Logger(PlatformAdminController.name);

  constructor(private platformService: PlatformAdminService) {}

  @Get('overview')
  getOverview() {
    return this.platformService.getOverview();
  }

  @Get('organizations')
  listOrganizations(
    @Query('search') search?: string,
    @Query('status') status?: string,
    @Query('page') page?: string,
    @Query('limit') limit?: string,
  ) {
    return this.platformService.listOrganizations({
      search,
      status,
      page,
      limit,
    } as any);
  }

  @Get('organizations/:id')
  getOrganization(@Param('id') id: string) {
    return this.platformService.getOrganization(id);
  }

  @Patch('organizations/:id')
  @HttpCode(HttpStatus.OK)
  updateOrganization(
    @Param('id') id: string,
    @Body() dto: UpdatePlatformOrganizationDto,
  ) {
    this.logger.log(`Platform admin updating organization ${id}`);
    return this.platformService.updateOrganization(id, dto);
  }

  @Get('users')
  listUsers(
    @Query('search') search?: string,
    @Query('status') status?: string,
    @Query('page') page?: string,
    @Query('limit') limit?: string,
  ) {
    return this.platformService.listUsers({
      search,
      status,
      page,
      limit,
    } as any);
  }

  @Patch('users/:id')
  @HttpCode(HttpStatus.OK)
  updateUser(@Param('id') id: string, @Body() dto: UpdatePlatformUserDto) {
    this.logger.log(`Platform admin updating user ${id}`);
    return this.platformService.updateUser(id, dto);
  }

  @Get('subscriptions')
  listSubscriptions(
    @Query('page') page?: string,
    @Query('limit') limit?: string,
  ) {
    return this.platformService.listSubscriptions({ page, limit } as any);
  }

  @Get('payments')
  listPayments(
    @Query('search') search?: string,
    @Query('status') status?: string,
    @Query('page') page?: string,
    @Query('limit') limit?: string,
  ) {
    return this.platformService.listPayments({
      search,
      status,
      page,
      limit,
    } as any);
  }

  @Get('activity')
  listActivity(@Query('limit') limit?: string) {
    return this.platformService.listActivity(limit ? parseInt(limit, 10) : 50);
  }
}
