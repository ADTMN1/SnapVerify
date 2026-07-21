"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.PaymentController = void 0;
const common_1 = require("@nestjs/common");
const platform_express_1 = require("@nestjs/platform-express");
const client_1 = require("@prisma/client");
const payment_service_1 = require("./payment.service");
const verify_reference_dto_1 = require("./dto/verify-reference.dto");
const jwt_auth_guard_1 = require("../auth/guards/jwt-auth.guard");
const roles_guard_1 = require("../auth/guards/roles.guard");
const roles_decorator_1 = require("../auth/decorators/roles.decorator");
let PaymentController = class PaymentController {
    paymentService;
    constructor(paymentService) {
        this.paymentService = paymentService;
    }
    async verifyByReference(dto, req) {
        const { sub: userId, organizationId } = req.user;
        return this.paymentService.verifyByReference(dto.referenceNumber, organizationId, userId, dto.amount, dto.provider, dto.suffix);
    }
    async verifyByImage(file, req) {
        if (!file)
            throw new common_1.BadRequestException('Image file is required');
        const { sub: userId, organizationId } = req.user;
        return this.paymentService.verifyByImage(file.buffer, file.mimetype, organizationId, userId);
    }
};
exports.PaymentController = PaymentController;
__decorate([
    (0, common_1.Post)('verify'),
    (0, roles_decorator_1.Roles)(client_1.Role.OWNER, client_1.Role.MANAGER, client_1.Role.CASHIER, client_1.Role.WAITER),
    __param(0, (0, common_1.Body)()),
    __param(1, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [verify_reference_dto_1.VerifyReferenceDto, Object]),
    __metadata("design:returntype", Promise)
], PaymentController.prototype, "verifyByReference", null);
__decorate([
    (0, common_1.Post)('verify-image'),
    (0, roles_decorator_1.Roles)(client_1.Role.OWNER, client_1.Role.MANAGER, client_1.Role.CASHIER, client_1.Role.WAITER),
    (0, common_1.UseInterceptors)((0, platform_express_1.FileInterceptor)('image', {
        limits: { fileSize: 10 * 1024 * 1024 },
        fileFilter: (_req, file, cb) => {
            if (!file.mimetype.startsWith('image/')) {
                cb(new common_1.BadRequestException('Only image files are accepted'), false);
            }
            else {
                cb(null, true);
            }
        },
    })),
    __param(0, (0, common_1.UploadedFile)()),
    __param(1, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, Object]),
    __metadata("design:returntype", Promise)
], PaymentController.prototype, "verifyByImage", null);
exports.PaymentController = PaymentController = __decorate([
    (0, common_1.Controller)('payments'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard, roles_guard_1.RolesGuard),
    __metadata("design:paramtypes", [payment_service_1.PaymentService])
], PaymentController);
//# sourceMappingURL=payment.controller.js.map