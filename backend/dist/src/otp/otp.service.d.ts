import { PrismaService } from '../prisma/prisma.service';
import { ConfigService } from '@nestjs/config';
import { HttpService } from '@nestjs/axios';
export declare class OtpService {
    private prisma;
    private configService;
    private httpService;
    private readonly logger;
    constructor(prisma: PrismaService, configService: ConfigService, httpService: HttpService);
    private formatPhoneNumber;
    private hashOtp;
    private sendSms;
    generateOtp(phone: string): Promise<string>;
    verifyOtp(phone: string, code: string): Promise<boolean>;
    sendInvitationSms(phone: string, role: string): Promise<void>;
}
