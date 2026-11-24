import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { resolveAdminAuthSecrets } from '../../config/admin-auth-secrets';
import { AdminJwtPayload } from '../interfaces/admin-jwt-payload.interface';

/**
 * Validates the Bearer token in the Authorization header for admin endpoints.
 * Attaches the decoded payload to req.admin as { sub, email, role }.
 * Apply this guard before AdminRolesGuard.
 */
@Injectable()
export class AdminJwtAuthGuard implements CanActivate {
  private readonly accessSecret: string;

  constructor(
    private jwtService: JwtService,
    config: ConfigService,
  ) {
    this.accessSecret = resolveAdminAuthSecrets(config).accessSecret;
  }

  canActivate(context: ExecutionContext): boolean {
    const request = context.switchToHttp().getRequest();
    const authHeader: string = request.headers['authorization'] ?? '';

    if (!authHeader.startsWith('Bearer ')) {
      throw new UnauthorizedException(
        'Missing or invalid Authorization header',
      );
    }

    const token = authHeader.slice(7);

    try {
      const payload = this.jwtService.verify<AdminJwtPayload>(token, {
        secret: this.accessSecret,
      });

      // Attach admin context to the request
      request.admin = {
        sub: payload.sub,
        email: payload.email,
        role: payload.role,
      };

      return true;
    } catch {
      throw new UnauthorizedException('Invalid or expired access token');
    }
  }
}
