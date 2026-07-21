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
exports.PaymentAccountController = void 0;
const common_1 = require("@nestjs/common");
const client_1 = require("@prisma/client");
const payment_account_service_1 = require("./payment-account.service");
const create_payment_account_dto_1 = require("./dto/create-payment-account.dto");
const update_payment_account_dto_1 = require("./dto/update-payment-account.dto");
const jwt_auth_guard_1 = require("../auth/guards/jwt-auth.guard");
const roles_guard_1 = require("../auth/guards/roles.guard");
const branch_guard_1 = require("../auth/guards/branch.guard");
const roles_decorator_1 = require("../auth/decorators/roles.decorator");
let PaymentAccountController = class PaymentAccountController {
    paymentAccountService;
    constructor(paymentAccountService) {
        this.paymentAccountService = paymentAccountService;
    }
    create(dto, req) {
        const { organizationId } = req.user;
        return this.paymentAccountService.create(organizationId, dto);
    }
    findAll(req, branchId) {
        const { organizationId } = req.user;
        if (branchId) {
            return this.paymentAccountService.findByOrganizationAndBranch(organizationId, branchId);
        }
        return this.paymentAccountService.findAll(organizationId);
    }
    findOne(provider, req, branchId) {
        const { organizationId } = req.user;
        return this.paymentAccountService.findByProviderAndBranch(organizationId, provider, branchId);
    }
    update(provider, dto, req, branchId) {
        const { organizationId } = req.user;
        return this.paymentAccountService.update(organizationId, provider, branchId, dto);
    }
    remove(provider, req, branchId) {
        const { organizationId } = req.user;
        return this.paymentAccountService.remove(organizationId, provider, branchId);
    }
};
exports.PaymentAccountController = PaymentAccountController;
__decorate([
    (0, common_1.Post)(),
    (0, roles_decorator_1.Roles)(client_1.Role.OWNER),
    __param(0, (0, common_1.Body)()),
    __param(1, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [create_payment_account_dto_1.CreatePaymentAccountDto, Object]),
    __metadata("design:returntype", void 0)
], PaymentAccountController.prototype, "create", null);
__decorate([
    (0, common_1.Get)(),
    (0, roles_decorator_1.Roles)(client_1.Role.OWNER),
    __param(0, (0, common_1.Req)()),
    __param(1, (0, common_1.Query)('branchId')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String]),
    __metadata("design:returntype", void 0)
], PaymentAccountController.prototype, "findAll", null);
__decorate([
    (0, common_1.Get)(':provider'),
    (0, roles_decorator_1.Roles)(client_1.Role.OWNER),
    __param(0, (0, common_1.Param)('provider')),
    __param(1, (0, common_1.Req)()),
    __param(2, (0, common_1.Query)('branchId')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object, String]),
    __metadata("design:returntype", void 0)
], PaymentAccountController.prototype, "findOne", null);
__decorate([
    (0, common_1.Put)(':provider'),
    (0, roles_decorator_1.Roles)(client_1.Role.OWNER),
    __param(0, (0, common_1.Param)('provider')),
    __param(1, (0, common_1.Body)()),
    __param(2, (0, common_1.Req)()),
    __param(3, (0, common_1.Query)('branchId')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, update_payment_account_dto_1.UpdatePaymentAccountDto, Object, String]),
    __metadata("design:returntype", void 0)
], PaymentAccountController.prototype, "update", null);
__decorate([
    (0, common_1.Delete)(':provider'),
    (0, roles_decorator_1.Roles)(client_1.Role.OWNER),
    __param(0, (0, common_1.Param)('provider')),
    __param(1, (0, common_1.Req)()),
    __param(2, (0, common_1.Query)('branchId')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, Object, String]),
    __metadata("design:returntype", void 0)
], PaymentAccountController.prototype, "remove", null);
exports.PaymentAccountController = PaymentAccountController = __decorate([
    (0, common_1.Controller)('payment-accounts'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard, roles_guard_1.RolesGuard, branch_guard_1.BranchGuard),
    __metadata("design:paramtypes", [payment_account_service_1.PaymentAccountService])
], PaymentAccountController);
//# sourceMappingURL=payment-account.controller.js.map