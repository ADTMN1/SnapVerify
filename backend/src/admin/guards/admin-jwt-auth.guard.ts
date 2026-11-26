import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { resolveAdminAuthSecrets } from '../../config/admin-auth-secrets';
import { PrismaService } from '../../prisma/prisma.service';
import { AdminJwtPayload } from '../interfaces/admin-jwt-payload.interface';
import { resolveAdminRole } from '../services/admin-jwt.service';

/**
 * Validates the Bearer token in the Authorization header for admin endpoints,
 * then re-checks that the account is still active and still authorised.
 * Role comes from the database, not from the token, so demotion takes effect
 * immediately without waiting for access-token expiry.
 */
@Injectable()
export class AdminJwtAuthGuard implements CanActivate {
  private readonly accessSecret: string;

  constructor(
    private jwtService: JwtService,
    config: ConfigService,
    private prisma: PrismaService,
  ) {
    this.accessSecret = resolveAdminAuthSecrets(config).accessSecret;
  }

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request: {
      headers: Record<string, string | undefined>;
      admin?: AdminJwtPayload;
    } = context.switchToHttp().getRequest();
    const authHeader: string = request.headers['authorization'] ?? '';

    if (!authHeader.startsWith('Bearer ')) {
      throw new UnauthorizedException(
        'Missing or invalid Authorization header',
      );
    }

    const token = authHeader.slice(7);

    let payload: AdminJwtPayload;
    try {
      payload = this.jwtService.verify<AdminJwtPayload>(token, {
        secret: this.accessSecret,
      });
    } catch {
      throw new UnauthorizedException('Invalid or expired access token');
    }

    const user = await this.prisma.user.findUnique({
      where: { id: payload.sub },
      select: {
        status: true,
        isPlatformAdmin: true,
        userAssignments: { select: { role: true, status: true } },
      },
    });

    if (!user || user.status !== 'active') {
      throw new UnauthorizedException('Admin account is inactive');
    }

    request.admin = {
      ...payload,
      role: resolveAdminRole(user),
    };

    return true;
  }
}
