"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
var OtpService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.OtpService = void 0;
const common_1 = require("@nestjs/common");
const prisma_service_1 = require("../prisma/prisma.service");
const crypto = __importStar(require("crypto"));
const config_1 = require("@nestjs/config");
const axios_1 = require("@nestjs/axios");
const rxjs_1 = require("rxjs");
let OtpService = OtpService_1 = class OtpService {
    prisma;
    configService;
    httpService;
    logger = new common_1.Logger(OtpService_1.name);
    constructor(prisma, configService, httpService) {
        this.prisma = prisma;
        this.configService = configService;
        this.httpService = httpService;
    }
    formatPhoneNumber(phone) {
        let formatted = phone.replace(/\s+/g, '').replace(/^\+/, '');
        if (formatted.startsWith('09')) {
            formatted = '251' + formatted.slice(1);
        }
        else if (formatted.startsWith('9')) {
            formatted = '251' + formatted;
        }
        return formatted;
    }
    hashOtp(otp) {
        return crypto.createHash('sha256').update(otp).digest('hex');
    }
    async sendSms(phone, text) {
        const apiKey = this.configService.get('SMSETHIOPIA_API_KEY');
        const baseUrl = 'https://smsethiopia.et/api/sms/send';
        if (!apiKey) {
            this.logger.warn('SMSETHIOPIA_API_KEY not set, skipping SMS send');
            return;
        }
        this.logger.log(`Attempting to send SMS to ${phone} with text: ${text}`);
        try {
            const response = await (0, rxjs_1.firstValueFrom)(this.httpService.post(baseUrl, { msisdn: phone, text }, { headers: { KEY: apiKey } }));
            this.logger.log(`SMS sent successfully to ${phone}, response: ${JSON.stringify(response.data)}`);
        }
        catch (error) {
            this.logger.error(`Failed to send SMS to ${phone}:`, error.response?.data || error.message);
            throw new common_1.BadRequestException('Failed to send SMS');
        }
    }
    async generateOtp(phone) {
        const formattedPhone = this.formatPhoneNumber(phone);
        const tenMinutesAgo = new Date(Date.now() - 10 * 60 * 1000);
        const recentOtpCount = await this.prisma.otpCode.count({
            where: {
                phone: formattedPhone,
                createdAt: { gte: tenMinutesAgo },
            },
        });
        if (recentOtpCount >= 3) {
            throw new common_1.BadRequestException('Too many OTP requests. Please try again later.');
        }
        await this.prisma.otpCode.deleteMany({ where: { phone: formattedPhone } });
        const code = crypto.randomInt(100000, 999999).toString();
        const otpHash = this.hashOtp(code);
        const expiresAt = new Date(Date.now() + 5 * 60 * 1000);
        await this.prisma.otpCode.create({
            data: { phone: formattedPhone, otpHash, expiresAt },
        });
        await this.sendSms(formattedPhone, `Your OTP code is ${code}`);
        this.logger.debug(`[DEV ONLY] OTP for ${formattedPhone}: ${code}`);
        return code;
    }
    async verifyOtp(phone, code) {
        const formattedPhone = this.formatPhoneNumber(phone);
        const otp = await this.prisma.otpCode.findFirst({
            where: {
                phone: formattedPhone,
                isUsed: false,
                expiresAt: { gt: new Date() },
            },
            orderBy: { createdAt: 'desc' },
        });
        if (!otp) {
            throw new common_1.BadRequestException('OTP expired or not found');
        }
        if (otp.otpHash !== this.hashOtp(code)) {
            await this.prisma.otpCode.update({
                where: { id: otp.id },
                data: { attempts: { increment: 1 } },
            });
            throw new common_1.BadRequestException('Invalid OTP');
        }
        await this.prisma.otpCode.delete({
            where: { id: otp.id },
        });
        return true;
    }
    async sendInvitationSms(phone, role) {
        const formattedPhone = this.formatPhoneNumber(phone);
        const message = `You have been invited to join as ${role}. Please verify your phone number to complete registration.`;
        await this.sendSms(formattedPhone, message);
    }
};
exports.OtpService = OtpService;
exports.OtpService = OtpService = OtpService_1 = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService,
        config_1.ConfigService,
        axios_1.HttpService])
], OtpService);
//# sourceMappingURL=otp.service.js.map