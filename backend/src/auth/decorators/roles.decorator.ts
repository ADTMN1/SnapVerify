import { SetMetadata } from '@nestjs/common';
import { Role } from '@prisma/client';

export const ROLES_KEY = 'roles';

/**
 * Attach required roles to a route or controller.
 *
 * @example
 * \@Roles(Role.OWNER, Role.MANAGER)
 * \@Get('reports')
 * getReports() { ... }
 */
export const Roles = (...roles: Role[]) => SetMetadata(ROLES_KEY, roles);
