import type { PaymentProvider, PaymentStatus, Role, SubscriptionStatus } from '../types';

export const API_BASE_URL = import.meta.env.VITE_API_URL ?? 'http://localhost:3000';

// ── Navigation ────────────────────────────────────────────────────────────────

export interface NavItem {
  id: string;
  label: string;
  icon: string;
  path: string;
  badge?: number;
  children?: NavItem[];
  roles?: Role[];
}

export const NAV_ITEMS: NavItem[] = [
  { id: 'dashboard',    label: 'Dashboard',         icon: 'LayoutDashboard', path: '/admin' },
  { id: 'transactions', label: 'Transactions',       icon: 'Receipt',         path: '/admin/transactions' },
  { id: 'live',         label: 'Live Monitor',       icon: 'Activity',        path: '/admin/live' },
  { id: 'fraud',        label: 'Fraud Center',       icon: 'ShieldAlert',     path: '/admin/fraud' },
  { id: 'employees',    label: 'Employees',          icon: 'Users',           path: '/admin/employees' },
  { id: 'branches',     label: 'Branches',           icon: 'Building2',       path: '/admin/branches' },
  { id: 'providers',    label: 'Payment Providers',  icon: 'CreditCard',      path: '/admin/providers' },
  { id: 'ocr',          label: 'OCR Verification',   icon: 'ScanLine',        path: '/admin/ocr' },
  { id: 'reports',      label: 'Reports',            icon: 'BarChart3',       path: '/admin/reports' },
  { id: 'analytics',    label: 'Analytics',          icon: 'TrendingUp',      path: '/admin/analytics' },
  { id: 'audit',        label: 'Audit Logs',         icon: 'ClipboardList',   path: '/admin/audit' },
  { id: 'devices',      label: 'Devices',            icon: 'Smartphone',      path: '/admin/devices' },
  { id: 'notifications',label: 'Notifications',      icon: 'Bell',            path: '/admin/notifications' },
  { id: 'profile',      label: 'Business Profile',   icon: 'Building',        path: '/admin/profile' },
  { id: 'roles',        label: 'Users & Roles',      icon: 'ShieldCheck',     path: '/admin/roles' },
  { id: 'subscription', label: 'Subscription',       icon: 'Zap',             path: '/admin/subscription' },
  { id: 'api',          label: 'API Monitoring',     icon: 'Webhook',         path: '/admin/api' },
  { id: 'login-history',label: 'Login History',      icon: 'History',         path: '/admin/login-history' },
  { id: 'support',      label: 'Support',            icon: 'LifeBuoy',        path: '/admin/support' },
  { id: 'settings',     label: 'Settings',           icon: 'Settings',        path: '/admin/settings' },
];

// ── Provider display ──────────────────────────────────────────────────────────

export const PROVIDER_LABELS: Record<PaymentProvider, string> = {
  CBE:       'CBE',
  TELEBIRR:  'Telebirr',
  DASHEN:    'Dashen',
  ABYSSINIA: 'Abyssinia',
  CBEBIRR:   'CBE Birr',
  M_PESA:    'M-Pesa',
};

export const PROVIDER_COLORS: Record<PaymentProvider, string> = {
  CBE:       '#0ea5e9',
  TELEBIRR:  '#a78bfa',
  DASHEN:    '#f59e0b',
  ABYSSINIA: '#10b981',
  CBEBIRR:   '#38bdf8',
  M_PESA:    '#ef4444',
};

// ── Status display ────────────────────────────────────────────────────────────

export const PAYMENT_STATUS_LABELS: Record<PaymentStatus, string> = {
  PENDING:  'Pending',
  VERIFIED: 'Verified',
  REJECTED: 'Rejected',
  FAILED:   'Failed',
};

export const PAYMENT_STATUS_COLORS: Record<PaymentStatus, { bg: string; text: string; border: string }> = {
  PENDING:  { bg: 'rgba(251,191,36,0.12)',  text: '#fbbf24', border: 'rgba(251,191,36,0.3)'  },
  VERIFIED: { bg: 'rgba(184,255,59,0.12)',  text: '#B8FF3B', border: 'rgba(184,255,59,0.3)'  },
  REJECTED: { bg: 'rgba(239,68,68,0.12)',   text: '#ef4444', border: 'rgba(239,68,68,0.3)'   },
  FAILED:   { bg: 'rgba(239,68,68,0.12)',   text: '#f87171', border: 'rgba(239,68,68,0.3)'   },
};

export const ROLE_LABELS: Record<Role, string> = {
  OWNER:   'Owner',
  MANAGER: 'Manager',
  CASHIER: 'Cashier',
  WAITER:  'Waiter',
};

export const ROLE_COLORS: Record<Role, { bg: string; text: string }> = {
  OWNER:   { bg: 'rgba(184,255,59,0.12)',  text: '#B8FF3B' },
  MANAGER: { bg: 'rgba(14,165,233,0.12)',  text: '#0ea5e9' },
  CASHIER: { bg: 'rgba(167,139,250,0.12)', text: '#a78bfa' },
  WAITER:  { bg: 'rgba(163,230,53,0.12)',  text: '#a3e635' },
};

export const SUBSCRIPTION_STATUS_COLORS: Record<SubscriptionStatus, { bg: string; text: string }> = {
  ACTIVE:    { bg: 'rgba(184,255,59,0.12)', text: '#B8FF3B' },
  INACTIVE:  { bg: 'rgba(100,116,139,0.2)', text: '#94a3b8' },
  CANCELLED: { bg: 'rgba(239,68,68,0.12)',  text: '#ef4444' },
  EXPIRED:   { bg: 'rgba(251,191,36,0.12)', text: '#fbbf24' },
};

// ── Risk score thresholds ─────────────────────────────────────────────────────

export const RISK_THRESHOLDS = { low: 30, medium: 60, high: 80 };

export function getRiskLevel(score: number): 'low' | 'medium' | 'high' | 'critical' {
  if (score <= RISK_THRESHOLDS.low)    return 'low';
  if (score <= RISK_THRESHOLDS.medium) return 'medium';
  if (score <= RISK_THRESHOLDS.high)   return 'high';
  return 'critical';
}

export const RISK_COLORS = {
  low:      { bg: 'rgba(184,255,59,0.12)',  text: '#B8FF3B' },
  medium:   { bg: 'rgba(251,191,36,0.12)',  text: '#fbbf24' },
  high:     { bg: 'rgba(239,68,68,0.12)',   text: '#ef4444' },
  critical: { bg: 'rgba(220,38,38,0.2)',    text: '#dc2626' },
};
