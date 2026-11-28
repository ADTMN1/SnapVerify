import { SetMetadata } from '@nestjs/common';
import { Permission } from '../permissions';

export const PERMISSIONS_KEY = 'permissions';

/**
 * Requires the authenticated user to have one of the specified permissions.
 *
 * Usage:
 *   @Permissions(Permission.ADD_STAFF)
 *   @Post('staff')
 *   addStaff(...) { ... }
 */
export const Permissions = (...permissions: Permission[]) =>
  SetMetadata(PERMISSIONS_KEY, permissions);
