import { Role } from '@prisma/client';
export declare enum Permission {
    ADD_STAFF = "ADD_STAFF",
    REMOVE_STAFF = "REMOVE_STAFF",
    ADD_MANAGER = "ADD_MANAGER",
    REMOVE_MANAGER = "REMOVE_MANAGER",
    ADD_BRANCH = "ADD_BRANCH",
    REMOVE_BRANCH = "REMOVE_BRANCH",
    VIEW_ALL_BRANCHES = "VIEW_ALL_BRANCHES",
    ADD_PAYMENT_ACCOUNT = "ADD_PAYMENT_ACCOUNT",
    EDIT_PAYMENT_ACCOUNT = "EDIT_PAYMENT_ACCOUNT",
    REMOVE_PAYMENT_ACCOUNT = "REMOVE_PAYMENT_ACCOUNT",
    GENERATE_QR_CODE = "GENERATE_QR_CODE",
    VIEW_QR_CODE = "VIEW_QR_CODE",
    EXPORT_REPORTS = "EXPORT_REPORTS",
    CAPTURE_PAYMENT = "CAPTURE_PAYMENT",
    VERIFY_PAYMENT = "VERIFY_PAYMENT"
}
export declare const ROLE_PERMISSIONS: Record<Role, Permission[]>;
export declare function hasPermission(role: Role, permission: Permission): boolean;
export declare function hasAllPermissions(role: Role, permissions: Permission[]): boolean;
export declare function hasAnyPermission(role: Role, permissions: Permission[]): boolean;
