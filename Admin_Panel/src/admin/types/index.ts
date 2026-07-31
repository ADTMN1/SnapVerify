// ── Enums (mirrored from Prisma schema) ──────────────────────────────────────

export type Role = 'OWNER' | 'MANAGER' | 'CASHIER' | 'WAITER';

export type PaymentStatus = 'PENDING' | 'VERIFIED' | 'REJECTED' | 'FAILED';

export type PaymentProvider = 'CBE' | 'TELEBIRR' | 'DASHEN' | 'ABYSSINIA' | 'CBEBIRR' | 'M_PESA';

export type VerificationStatus = 'PENDING' | 'SUCCESS' | 'FAILED';

export type SubscriptionStatus = 'ACTIVE' | 'INACTIVE' | 'CANCELLED' | 'EXPIRED';

// ── Models ────────────────────────────────────────────────────────────────────

export interface Organization {
  id: string;
  name: string;
  type: string;
  phone: string;
  email?: string;
  address?: string;
  city?: string;
  country?: string;
  logoUrl?: string;
  subscriptionPlan?: string;
  status: string;
  createdAt: string;
  updatedAt: string;
}

export interface User {
  id: string;
  fullName?: string;
  phone: string;
  email?: string;
  status: string;
  createdAt: string;
  updatedAt: string;
}

export interface UserBusinessAssignment {
  id: string;
  userId: string;
  organizationId: string;
  branchId?: string;
  role: Role;
  status: string;
  createdAt: string;
  updatedAt: string;
  user?: User;
  branch?: Branch;
}

export interface Branch {
  id: string;
  organizationId: string;
  name: string;
  address?: string;
  latitude?: number;
  longitude?: number;
  phone?: string;
  createdAt: string;
  updatedAt: string;
}

export interface Payment {
  id: string;
  organizationId: string;
  userId?: string;
  amount: number;
  currency: string;
  paymentMethod: string;
  transactionId: string;
  senderName?: string;
  receiverName?: string;
  status: PaymentStatus;
  riskScore?: number;
  rawData?: Record<string, unknown>;
  createdAt: string;
  updatedAt: string;
  user?: User;
  verificationLogs?: VerificationLog[];
}

export interface VerificationLog {
  id: string;
  organizationId?: string;
  paymentId?: string;
  userId?: string;
  action: string;
  reason?: string;
  riskScore?: number;
  matchedProvider?: PaymentProvider;
  matchedAccountNumber?: string;
  matchedSuffix?: string;
  matchedBranchId?: string;
  matchedPaymentAccountId?: string;
  createdAt: string;
  user?: User;
  payment?: Payment;
}

export interface PaymentAccount {
  id: string;
  organizationId: string;
  branchId?: string;
  provider: PaymentProvider;
  accountNumber?: string;
  suffix?: string;
  accountHolderName?: string;
  isActive: boolean;
  createdAt: string;
  updatedAt: string;
  branch?: Branch;
}

export interface Subscription {
  id: string;
  organizationId: string;
  planName: string;
  status: SubscriptionStatus;
  startDate: string;
  endDate?: string;
  maxUsers?: number;
  maxDevices?: number;
  createdAt: string;
  updatedAt: string;
}

export interface ActivityLog {
  id: string;
  organizationId: string;
  userId?: string;
  action: string;
  metadata?: Record<string, unknown>;
  ipAddress?: string;
  createdAt: string;
  user?: User;
}

export interface Device {
  id: string;
  userAssignmentId: string;
  deviceFingerprint: string;
  deviceName?: string;
  isActive: boolean;
  lastLoginAt: string;
  createdAt: string;
  userAssignment?: UserBusinessAssignment;
}

export interface Invitation {
  id: string;
  phone: string;
  organizationId: string;
  branchId?: string;
  role: Role;
  status: string;
  createdAt: string;
  updatedAt: string;
}

export interface RefreshToken {
  id: string;
  userId: string;
  organizationId: string;
  role: string;
  expiresAt: string;
  deviceInfo?: string;
  ipAddress?: string;
  createdAt: string;
}

// ── Auth ──────────────────────────────────────────────────────────────────────

export interface AuthTokens {
  accessToken: string;
  refreshToken: string;
}

export interface AuthUser {
  id: string;
  fullName?: string;
  phone: string;
  email?: string;
  status: string;
  createdAt: string;
  updatedAt: string;
}

export interface AuthState {
  user: AuthUser | null;
  organization: Organization | null;
  tokens: AuthTokens | null;
  role: Role | null;
  isAuthenticated: boolean;
  isLoading: boolean;
}

// ── API Response wrappers ─────────────────────────────────────────────────────

export interface PaginatedResponse<T> {
  data: T[];
  total: number;
  page: number;
  limit: number;
}

export interface ApiError {
  message: string;
  statusCode: number;
}

// ── Dashboard Stats ───────────────────────────────────────────────────────────

export interface DashboardStats {
  totalVerified: number;
  totalPending: number;
  totalFailed: number;
  fraudAlerts: number;
  todayRevenue: number;
  todayTransactions: number;
  activeEmployees: number;
  activeBranches: number;
}

export interface ChartDataPoint {
  date: string;
  value: number;
  label?: string;
}

export interface ProviderChartData {
  provider: PaymentProvider;
  count: number;
  amount: number;
}

// ── Table / Filter ────────────────────────────────────────────────────────────

export interface TableColumn<T> {
  key: keyof T | string;
  label: string;
  sortable?: boolean;
  render?: (value: unknown, row: T) => React.ReactNode;
  width?: string;
}

export interface FilterOption {
  label: string;
  value: string;
}

export interface SortConfig {
  key: string;
  direction: 'asc' | 'desc';
}
