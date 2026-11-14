import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { Role } from '@prisma/client';
import { ROLES_KEY } from '../decorators/roles.decorator';
import { Permission, hasAnyPermission, hasPermission } from '../permissions';
import { PERMISSIONS_KEY } from '../decorators/permissions.decorator';

/**
 * Must be applied **after** JwtAuthGuard so that req.user is already populated.
 *
 * Supports two styles of authorization (both work, either is sufficient):
 *   1) @Roles(Role.OWNER, Role.MANAGER)   — classic role list
 *   2) @Permissions(Permission.ADD_STAFF) — granular permission check
 *
 * If neither decorator is present the guard allows through (open to all
 * authenticated users).
 */
@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const requiredRoles = this.reflector.getAllAndOverride<Role[]>(ROLES_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);
    const requiredPermissions = this.reflector.getAllAndOverride<Permission[]>(
      PERMISSIONS_KEY,
      [context.getHandler(), context.getClass()],
    );

    // No roles nor permissions → any authenticated user is allowed
    if (
      (!requiredRoles || requiredRoles.length === 0) &&
      (!requiredPermissions || requiredPermissions.length === 0)
    ) {
      return true;
    }

    const { user } = context.switchToHttp().getRequest();

    if (!user?.role) {
      throw new ForbiddenException(
        'You do not have permission to access this resource.',
      );
    }

    const role = user.role as Role;

    // Check permissions (if decorator present)
    if (requiredPermissions && requiredPermissions.length > 0) {
      const ok = hasAnyPermission(role, requiredPermissions);
      if (!ok) {
        throw new ForbiddenException(
          'You do not have permission to perform this action.',
        );
      }
      return true;
    }

    // Check roles (if decorator present)
    if (requiredRoles && requiredRoles.length > 0) {
      if (!requiredRoles.includes(role)) {
        throw new ForbiddenException(
          'You do not have permission to access this feature.',
        );
      }
      return true;
    }

    return true;
  }
}

/**
 * Expose helper so other guards / services can re-use the permission lookup.
 */
export { hasPermission };
