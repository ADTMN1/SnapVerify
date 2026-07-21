import { CanActivate, ExecutionContext } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
export interface JwtPayload {
    sub: string;
    organizationId: string;
    role: string;
    branchId?: string;
    iat: number;
    exp: number;
}
export declare class JwtAuthGuard implements CanActivate {
    private jwtService;
    private config;
    constructor(jwtService: JwtService, config: ConfigService);
    canActivate(context: ExecutionContext): boolean;
}
