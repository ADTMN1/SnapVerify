import { Controller, Get, Post, Req, UseGuards } from '@nestjs/common';
import { Role } from '@prisma/client';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { NotificationsService } from './notifications.service';

/**
 * Notification feed endpoints.
 *
 * The feed is derived from real organization activity and scoped to the
 * caller's organization (and to the caller's own payments for non-privileged
 * roles).
 */
@Controller('notifications')
@UseGuards(JwtAuthGuard, RolesGuard)
export class NotificationsController {
  constructor(private readonly notificationsService: NotificationsService) {}

  @Get()
  @Roles(Role.OWNER, Role.MANAGER, Role.CASHIER, Role.WAITER)
  getFeed(@Req() req: any) {
    const { sub: userId, organizationId, role } = req.user;
    return this.notificationsService.getFeed({
      organizationId,
      userId,
      role,
    });
  }

  @Post('read')
  @Roles(Role.OWNER, Role.MANAGER, Role.CASHIER, Role.WAITER)
  markAllRead(@Req() req: any) {
    return this.notificationsService.markAllRead(req.user.sub);
  }
}
