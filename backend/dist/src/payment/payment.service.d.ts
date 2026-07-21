import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../prisma/prisma.service';
export declare class PaymentService {
    private config;
    private prisma;
    private readonly logger;
    private readonly apiKey;
    private readonly baseUrl;
    private readonly skipPrimaryVerification;
    constructor(config: ConfigService, prisma: PrismaService);
    private _detectProvider;
    private _isPaymentToAccount;
    private _maskSensitive;
    verifyByReference(referenceNumber: string, organizationId: string, userId: string, amount?: number, provider?: string, extractedSuffix?: string): Promise<{
        verified: boolean;
        status: "VERIFIED" | "FAILED";
        paymentId: any;
        amount: number;
        currency: string;
        transactionId: any;
        senderName: any;
        receiverName: any;
        riskScore: number;
        message: any;
        raw: any;
    } | {
        verified: boolean;
        status: string;
        paymentId: string;
        amount: number;
        currency: string;
        transactionId: string;
        senderName: string | null;
        receiverName: string | null;
        riskScore: number | null;
        message: string;
        raw: null;
    }>;
    private _verifyWithSuffix;
    verifyByImage(imageBuffer: Buffer, mimeType: string, organizationId: string, userId: string): Promise<{
        verified: boolean;
        status: "VERIFIED" | "FAILED";
        paymentId: any;
        amount: number;
        currency: string;
        transactionId: any;
        senderName: any;
        receiverName: any;
        riskScore: number;
        message: any;
        raw: any;
    }>;
    private _fetchJson;
    private _saveAndReturn;
}
