"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.ROLE_PERMISSIONS = exports.Permission = void 0;
exports.hasPermission = hasPermission;
exports.hasAllPermissions = hasAllPermissions;
exports.hasAnyPermission = hasAnyPermission;
const client_1 = require("@prisma/client");
var Permission;
(function (Permission) {
    Permission["ADD_STAFF"] = "ADD_STAFF";
    Permission["REMOVE_STAFF"] = "REMOVE_STAFF";
    Permission["ADD_MANAGER"] = "ADD_MANAGER";
    Permission["REMOVE_MANAGER"] = "REMOVE_MANAGER";
    Permission["ADD_BRANCH"] = "ADD_BRANCH";
    Permission["REMOVE_BRANCH"] = "REMOVE_BRANCH";
    Permission["VIEW_ALL_BRANCHES"] = "VIEW_ALL_BRANCHES";
    Permission["ADD_PAYMENT_ACCOUNT"] = "ADD_PAYMENT_ACCOUNT";
    Permission["EDIT_PAYMENT_ACCOUNT"] = "EDIT_PAYMENT_ACCOUNT";
    Permission["REMOVE_PAYMENT_ACCOUNT"] = "REMOVE_PAYMENT_ACCOUNT";
    Permission["GENERATE_QR_CODE"] = "GENERATE_QR_CODE";
    Permission["VIEW_QR_CODE"] = "VIEW_QR_CODE";
    Permission["EXPORT_REPORTS"] = "EXPORT_REPORTS";
    Permission["CAPTURE_PAYMENT"] = "CAPTURE_PAYMENT";
    Permission["VERIFY_PAYMENT"] = "VERIFY_PAYMENT";
})(Permission || (exports.Permission = Permission = {}));
exports.ROLE_PERMISSIONS = {
    [client_1.Role.OWNER]: [
        Permission.ADD_STAFF,
        Permission.REMOVE_STAFF,
        Permission.ADD_MANAGER,
        Permission.REMOVE_MANAGER,
        Permission.ADD_BRANCH,
        Permission.REMOVE_BRANCH,
        Permission.VIEW_ALL_BRANCHES,
        Permission.ADD_PAYMENT_ACCOUNT,
        Permission.EDIT_PAYMENT_ACCOUNT,
        Permission.REMOVE_PAYMENT_ACCOUNT,
        Permission.GENERATE_QR_CODE,
        Permission.VIEW_QR_CODE,
        Permission.EXPORT_REPORTS,
        Permission.CAPTURE_PAYMENT,
        Permission.VERIFY_PAYMENT,
    ],
    [client_1.Role.MANAGER]: [
        Permission.ADD_STAFF,
        Permission.REMOVE_STAFF,
        Permission.ADD_BRANCH,
        Permission.REMOVE_BRANCH,
        Permission.ADD_PAYMENT_ACCOUNT,
        Permission.EDIT_PAYMENT_ACCOUNT,
        Permission.REMOVE_PAYMENT_ACCOUNT,
        Permission.GENERATE_QR_CODE,
        Permission.VIEW_QR_CODE,
        Permission.EXPORT_REPORTS,
        Permission.CAPTURE_PAYMENT,
        Permission.VERIFY_PAYMENT,
    ],
    [client_1.Role.CASHIER]: [
        Permission.VIEW_QR_CODE,
        Permission.EXPORT_REPORTS,
        Permission.CAPTURE_PAYMENT,
        Permission.VERIFY_PAYMENT,
    ],
    [client_1.Role.WAITER]: [
        Permission.VIEW_QR_CODE,
        Permission.CAPTURE_PAYMENT,
        Permission.VERIFY_PAYMENT,
    ],
};
function hasPermission(role, permission) {
    return exports.ROLE_PERMISSIONS[role]?.includes(permission) ?? false;
}
function hasAllPermissions(role, permissions) {
    return permissions.every(permission => hasPermission(role, permission));
}
function hasAnyPermission(role, permissions) {
    return permissions.some(permission => hasPermission(role, permission));
}
//# sourceMappingURL=permissions.js.map