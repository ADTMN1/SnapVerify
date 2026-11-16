import { SetMetadata } from '@nestjs/common';

export const IS_PUBLIC_KEY = 'isPublic';

/**
 * Marks a route (or entire controller) as public — bypasses JwtAuthGuard.
 *
 * Use on endpoints accessed before login:
 *   login, create-business, activate-invitation, check-invitation
 */
export const Public = () => SetMetadata(IS_PUBLIC_KEY, true);
