import axios, { type AxiosRequestConfig } from 'axios';
import type {
  Branch, UserBusinessAssignment, PaymentAccount, Device, Subscription,
  PlatformOverview, PlatformOrganization, PlatformUser, PlatformSubscription,
  PlatformActivity, PlatformPaymentsResult, PlatformPaymentAccount, Paginated,
  SubscriptionPlan,
} from '../types';
import { API_BASE_URL } from '../constants';

const api = axios.create({ baseURL: API_BASE_URL });

api.interceptors.request.use(cfg => {
  const token = localStorage.getItem('sv_admin_token') || localStorage.getItem('sv_access_token');
  if (token) cfg.headers.Authorization = `Bearer ${token}`;
  return cfg;
});

type RetryableConfig = AxiosRequestConfig & { _retry?: boolean };
let adminRefreshInFlight: Promise<string | null> | null = null;

function clearAdminSession(): void {
  localStorage.removeItem('sv_admin_token');
  localStorage.removeItem('sv_admin_refresh_token');
  if (typeof window !== 'undefined') {
    window.dispatchEvent(new Event('sv-admin-session-expired'));
  }
}

api.interceptors.response.use(
  response => response,
  async error => {
    const config = error.config as RetryableConfig | undefined;
    if (!config || error.response?.status !== 401) return Promise.reject(error);

    const url = config.url ?? '';
    // Only the public auth endpoints must skip the refresh flow. Protected
    // calls like /api/admin/auth/me, /change-password and /profile SHOULD
    // refresh on 401 — otherwise an expired access token logs the admin out.
    const isAuthCall =
      /\/api\/admin\/auth\/(login|refresh|forgot-password|reset-password)/.test(url) ||
      /\/auth\/(login|refresh)/.test(url);
    if (isAuthCall) {
      if (url.includes('/refresh')) clearAdminSession();
      return Promise.reject(error);
    }

    // A retried request that still fails must not trigger another refresh.
    if (config._retry) {
      clearAdminSession();
      return Promise.reject(error);
    }
    config._retry = true;

    if (!adminRefreshInFlight) {
      const refreshToken = localStorage.getItem('sv_admin_refresh_token');
      if (!refreshToken) {
        clearAdminSession();
        return Promise.reject(error);
      }
      // Use plain axios so the refresh call cannot recurse into this
      // interceptor. Concurrent 401s share one refresh request.
      adminRefreshInFlight = axios
        .post(`${API_BASE_URL}/api/admin/auth/refresh`, { refreshToken })
        .then(res => {
          const tokens = res.data?.tokens as
            | { accessToken: string; refreshToken: string }
            | undefined;
          if (!tokens?.accessToken) return null;
          localStorage.setItem('sv_admin_token', tokens.accessToken);
          localStorage.setItem('sv_admin_refresh_token', tokens.refreshToken);
          return tokens.accessToken;
        })
        .catch(() => {
          clearAdminSession();
          return null;
        })
        .finally(() => {
          adminRefreshInFlight = null;
        });
    }

    const accessToken = await adminRefreshInFlight;
    if (!accessToken) return Promise.reject(error);

    config.headers = {
      ...(config.headers ?? {}),
      Authorization: `Bearer ${accessToken}`,
    };
    return api(config);
  },
);

export const authApi = {
  login: (phone: string, password: string, organizationId?: string) =>
    api.post('/auth/login', { phone, password, organizationId }),
  me: () => api.get('/auth/me'),
  logout: (refreshToken: string) => api.post('/auth/logout', { refreshToken }),
  logoutAll: () => api.post('/auth/logout-all'),
  changePassword: (currentPassword: string, newPassword: string) =>
    api.post('/auth/change-password', { currentPassword, newPassword }),
};

export const adminAuthApi = {
  login: (email: string, password: string) =>
    api.post('/api/admin/auth/login', { email, password }),
  me: () => api.get('/api/admin/auth/me'),
  refresh: (refreshToken: string) => api.post('/api/admin/auth/refresh', { refreshToken }),
  logout: (refreshToken: string) => api.post('/api/admin/auth/logout', { refreshToken }),
  logoutAll: () => api.post('/api/admin/auth/logout-all'),
  changePassword: (currentPassword: string, newPassword: string) =>
    api.post('/api/admin/auth/change-password', { currentPassword, newPassword }),
  updateProfile: (currentPassword: string, newEmail?: string) =>
    api.patch('/api/admin/auth/profile', { currentPassword, newEmail }),
};

export const adminDashboardApi = {
  stats: () => api.get('/api/admin/dashboard/stats'),
  activity: (limit?: number) => api.get('/api/admin/dashboard/activity', { params: { limit } }),
  payments: (limit?: number) => api.get('/api/admin/dashboard/payments', { params: { limit } }),
  revenueTrend: (days?: number) => api.get('/api/admin/dashboard/revenue-trend', { params: { days } }),
  verificationTrend: (days?: number) => api.get('/api/admin/dashboard/verification-trend', { params: { days } }),
  providerStats: () => api.get('/api/admin/dashboard/provider-stats'),
  branchPerformance: () => api.get('/api/admin/dashboard/branch-performance'),
};

export const adminDataApi = {
  organization: () => api.get('/api/admin/data/organization'),
  payments: (params?: { page?: number; limit?: number; status?: string; search?: string }) =>
    api.get('/api/admin/data/payments', { params }),
  staff: () => api.get<UserBusinessAssignment[]>('/api/admin/data/staff'),
  branches: () => api.get<Branch[]>('/api/admin/data/branches'),
  paymentAccounts: () => api.get<PaymentAccount[]>('/api/admin/data/payment-accounts'),
  auditLogs: (params?: { page?: number; limit?: number; action?: string; search?: string }) =>
    api.get('/api/admin/data/audit-logs', { params }),
  devices: () => api.get<Device[]>('/api/admin/data/devices'),
  loginHistory: (params?: { page?: number; limit?: number }) =>
    api.get('/api/admin/data/login-history', { params }),
  subscription: () => api.get<Subscription>('/api/admin/data/subscription'),
  subscriptionAccount: () => api.get<PlatformPaymentAccount>('/api/admin/data/subscription-account'),
  updateSubscriptionAccount: (data: {
    accountNumber: string;
    accountHolderName?: string;
    isActive?: boolean;
  }) => api.put<PlatformPaymentAccount>('/api/admin/data/subscription-account', data),
  fraud: (params?: { page?: number; limit?: number; minRisk?: number }) =>
    api.get('/api/admin/data/fraud', { params }),
  blockDevice: (id: string) => api.patch(`/api/admin/data/devices/${id}/block`),
  removeDevice: (id: string) => api.delete(`/api/admin/data/devices/${id}`),
};

export const platformAdminApi = {
  overview: () => api.get<PlatformOverview>('/api/admin/platform/overview'),
  organizations: (params?: { page?: number; limit?: number; status?: string; search?: string }) =>
    api.get<Paginated<PlatformOrganization>>('/api/admin/platform/organizations', { params }),
  organization: (id: string) =>
    api.get<PlatformOrganization>(`/api/admin/platform/organizations/${id}`),
  updateOrganization: (id: string, data: { status?: string; subscriptionPlan?: string }) =>
    api.patch<PlatformOrganization>(`/api/admin/platform/organizations/${id}`, data),
  users: (params?: { page?: number; limit?: number; status?: string; search?: string }) =>
    api.get<Paginated<PlatformUser>>('/api/admin/platform/users', { params }),
  updateUser: (id: string, data: { status?: string; isPlatformAdmin?: boolean }) =>
    api.patch<PlatformUser>(`/api/admin/platform/users/${id}`, data),
  subscriptions: (params?: { page?: number; limit?: number }) =>
    api.get<Paginated<PlatformSubscription>>('/api/admin/platform/subscriptions', { params }),
  payments: (params?: { page?: number; limit?: number; status?: string; search?: string }) =>
    api.get<PlatformPaymentsResult>('/api/admin/platform/payments', { params }),
  activity: (limit?: number) =>
    api.get<PlatformActivity[]>('/api/admin/platform/activity', { params: { limit } }),
  plans: () => api.get<SubscriptionPlan[]>('/api/admin/platform/plans'),
  createPlan: (data: Partial<SubscriptionPlan> & { name: string; price: number }) =>
    api.post<SubscriptionPlan>('/api/admin/platform/plans', data),
  updatePlan: (id: string, data: Partial<SubscriptionPlan>) =>
    api.patch<SubscriptionPlan>(`/api/admin/platform/plans/${id}`, data),
};

export const branchApi = {
  list: () => api.get<Branch[]>('/branches'),
  create: (data: { name: string; address?: string; phone?: string }) => api.post<Branch>('/branches', data),
  update: (id: string, data: Partial<Branch>) => api.patch<Branch>(`/branches/${id}`, data),
  remove: (id: string) => api.delete(`/branches/${id}`),
};

export const paymentAccountApi = {
  list: (branchId?: string) =>
    api.get<PaymentAccount[]>('/payment-accounts', { params: branchId ? { branchId } : {} }),
  create: (data: Partial<PaymentAccount>) => api.post<PaymentAccount>('/payment-accounts', data),
  update: (provider: string, data: Partial<PaymentAccount>, branchId?: string) =>
    api.put<PaymentAccount>(`/payment-accounts/${provider}`, data, { params: branchId ? { branchId } : {} }),
  remove: (provider: string, branchId?: string) =>
    api.delete(`/payment-accounts/${provider}`, { params: branchId ? { branchId } : {} }),
};

export const staffApi = {
  add: (data: { fullName: string; username: string; role: string; branchId?: string }) =>
    api.post('/auth/staff', data),
  remove: (id: string) => api.delete(`/auth/staff/${id}`),
};

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

export default api;
