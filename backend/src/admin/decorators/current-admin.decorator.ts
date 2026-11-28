import { createParamDecorator, ExecutionContext } from '@nestjs/common';
import { AdminAuthContext } from '../interfaces/admin-jwt-payload.interface';

export const CurrentAdmin = createParamDecorator(
  (data: unknown, ctx: ExecutionContext): AdminAuthContext => {
    const request = ctx.switchToHttp().getRequest();
    return request.admin;
  },
);
