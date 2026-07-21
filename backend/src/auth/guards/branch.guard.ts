import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';
import { Role } from '@prisma/client';

/**
 * BranchGuard enforces branch-based access control.
 * 
 * - OWNER: Can access all branches (no restriction)
 * - MANAGER: Can only access their assigned branch
 * - CASHIER: Can only access their assigned branch
 * - WAITER: Can only access their assigned branch
 * 
 * This guard should be applied AFTER JwtAuthGuard so that req.user is populated.
 * It injects branchFilter into req for use in services.
 */
@Injectable()
export class BranchGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    const request = context.switchToHttp().getRequest();
    const user = request.user;

    if (!user) {
      throw new ForbiddenException('User not authenticated');
    }

    const role = user.role as Role;

    // OWNER can access all branches - no restriction
    if (role === Role.OWNER) {
      request.branchFilter = null; // No branch filter needed
      return true;
    }

    // For MANAGER, CASHIER, WAITER - they must have a branch assigned
    if (!user.branchId) {
      throw new ForbiddenException(
        `${role} must be assigned to a branch to perform this action`,
      );
    }

    // Inject branch filter for services to use
    request.branchFilter = user.branchId;

    // Check if the request is trying to access a different branch
    const requestedBranchId = request.params?.branchId || request.query?.branchId;

    if (requestedBranchId && requestedBranchId !== user.branchId) {
      throw new ForbiddenException(
        `${role} can only access their assigned branch`,
      );
    }

    return true;
  }
}
