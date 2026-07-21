import { PaymentService } from './payment.service';
import { VerifyReferenceDto } from './dto/verify-reference.dto';
export declare class PaymentController {
    private paymentService;
    constructor(paymentService: PaymentService);
    verifyByReference(dto: VerifyReferenceDto, req: any): Promise<{
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
    verifyByImage(file: Express.Multer.File, req: any): Promise<{
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
}
