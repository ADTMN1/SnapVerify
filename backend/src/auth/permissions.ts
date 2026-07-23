import { Role } from '@prisma/client';

/**
 * Permission flags for granular access control
 */
export enum Permission {
  // Staff Management
  ADD_STAFF = 'ADD_STAFF',
  REMOVE_STAFF = 'REMOVE_STAFF',
  ADD_MANAGER = 'ADD_MANAGER',
  REMOVE_MANAGER = 'REMOVE_MANAGER',

  // Branch Management
  ADD_BRANCH = 'ADD_BRANCH',
  REMOVE_BRANCH = 'REMOVE_BRANCH',
  VIEW_ALL_BRANCHES = 'VIEW_ALL_BRANCHES',

  // Payment Account Management
  ADD_PAYMENT_ACCOUNT = 'ADD_PAYMENT_ACCOUNT',
  EDIT_PAYMENT_ACCOUNT = 'EDIT_PAYMENT_ACCOUNT',
  REMOVE_PAYMENT_ACCOUNT = 'REMOVE_PAYMENT_ACCOUNT',

  // QR Code Management
  GENERATE_QR_CODE = 'GENERATE_QR_CODE',
  VIEW_QR_CODE = 'VIEW_QR_CODE',

  // Reports
  EXPORT_REPORTS = 'EXPORT_REPORTS',

  // Payment Operations
  CAPTURE_PAYMENT = 'CAPTURE_PAYMENT',
  VERIFY_PAYMENT = 'VERIFY_PAYMENT',
}

/**
 * Permission mapping for each role
 */
export const ROLE_PERMISSIONS: Record<Role, Permission[]> = {
  [Role.OWNER]: [
    // Staff Management - Full control
    Permission.ADD_STAFF,
    Permission.REMOVE_STAFF,
    Permission.ADD_MANAGER,
    Permission.REMOVE_MANAGER,

    // Branch Management - Full control over all branches
    Permission.ADD_BRANCH,
    Permission.REMOVE_BRANCH,
    Permission.VIEW_ALL_BRANCHES,

    // Payment Account Management - Full control
    Permission.ADD_PAYMENT_ACCOUNT,
    Permission.EDIT_PAYMENT_ACCOUNT,
    Permission.REMOVE_PAYMENT_ACCOUNT,

    // QR Code Management - Full control
    Permission.GENERATE_QR_CODE,
    Permission.VIEW_QR_CODE,

    // Reports
    Permission.EXPORT_REPORTS,

    // Payment Operations
    Permission.CAPTURE_PAYMENT,
    Permission.VERIFY_PAYMENT,
  ],

  [Role.MANAGER]: [
    // Staff Management - Can add/remove staff but not managers
    Permission.ADD_STAFF,
    Permission.REMOVE_STAFF,

    // Branch Management - Can manage assigned branch only
    Permission.ADD_BRANCH,
    Permission.REMOVE_BRANCH,

    // Payment Account Management - Full control for assigned branch
    Permission.ADD_PAYMENT_ACCOUNT,
    Permission.EDIT_PAYMENT_ACCOUNT,
    Permission.REMOVE_PAYMENT_ACCOUNT,

    // QR Code Management - Full control for assigned branch
    Permission.GENERATE_QR_CODE,
    Permission.VIEW_QR_CODE,

    // Reports
    Permission.EXPORT_REPORTS,

    // Payment Operations
    Permission.CAPTURE_PAYMENT,
    Permission.VERIFY_PAYMENT,
  ],

  [Role.CASHIER]: [
    // Staff Management - None

    // Branch Management - None

    // Payment Account Management - None

    // QR Code Management - Can only view
    Permission.VIEW_QR_CODE,

    // Reports
    Permission.EXPORT_REPORTS,

    // Payment Operations
    Permission.CAPTURE_PAYMENT,
    Permission.VERIFY_PAYMENT,
  ],

  [Role.WAITER]: [
    // Staff Management - None

    // Branch Management - None

    // Payment Account Management - None

    // QR Code Management - Can only view
    Permission.VIEW_QR_CODE,

    // Reports - None

    // Payment Operations
    Permission.CAPTURE_PAYMENT,
    Permission.VERIFY_PAYMENT,
  ],
};

/**
 * Check if a role has a specific permission
 */
export function hasPermission(role: Role, permission: Permission): boolean {
  return ROLE_PERMISSIONS[role]?.includes(permission) ?? false;
}

/**
 * Check if a role has all specified permissions
 */
export function hasAllPermissions(
  role: Role,
  permissions: Permission[],
): boolean {
  return permissions.every((permission) => hasPermission(role, permission));
}

/**
 * Check if a role has any of the specified permissions
 */
export function hasAnyPermission(
  role: Role,
  permissions: Permission[],
): boolean {
  return permissions.some((permission) => hasPermission(role, permission));
}
