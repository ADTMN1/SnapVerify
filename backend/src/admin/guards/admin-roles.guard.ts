import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { ADMIN_ROLES_KEY } from '../decorators/admin-roles.decorator';

/**
 * Must be applied **after** AdminJwtAuthGuard so that req.admin is already populated.
 *
 * If no @AdminRoles() decorator is present the guard allows through (open to all
 * authenticated admin users). To lock down a route, add @AdminRoles('SUPER_ADMIN').
 */
@Injectable()
export class AdminRolesGuard implements CanActivate {
  constructor(private reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const requiredRoles = this.reflector.getAllAndOverride<string[]>(
      ADMIN_ROLES_KEY,
      [context.getHandler(), context.getClass()],
    );

    // No @AdminRoles() decorator → any authenticated admin is allowed
    if (!requiredRoles || requiredRoles.length === 0) {
      return true;
    }

    const { admin } = context.switchToHttp().getRequest();

    if (!admin?.role) {
      throw new ForbiddenException('Access denied: no admin role assigned');
    }

    if (!requiredRoles.includes(admin.role)) {
      throw new ForbiddenException(
        `Access denied: requires one of [${requiredRoles.join(', ')}]`,
      );
    }

    return true;
  }
}
