import { SetMetadata } from '@nestjs/common';

export const ADMIN_ROLES_KEY = 'adminRoles';

/**
 * Attach required admin roles to a route or controller.
 *
 * @example
 * \@AdminRoles('SUPER_ADMIN', 'BUSINESS_OWNER')
 * \@Get('users')
 * getUsers() { ... }
 */
export const AdminRoles = (...roles: string[]) =>
  SetMetadata(ADMIN_ROLES_KEY, roles);
