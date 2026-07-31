import axios from 'axios';
import type { Branch, UserBusinessAssignment, PaymentAccount, Device, Subscription } from '../types';
import { API_BASE_URL } from '../constants';

const api = axios.create({ baseURL: API_BASE_URL });

api.interceptors.request.use(cfg => {
  const token = localStorage.getItem('sv_admin_token') || localStorage.getItem('sv_access_token');
  if (token) cfg.headers.Authorization = `Bearer ${token}`;
  return cfg;
});

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
  fraud: (params?: { page?: number; limit?: number; minRisk?: number }) =>
    api.get('/api/admin/data/fraud', { params }),
  blockDevice: (id: string) => api.patch(`/api/admin/data/devices/${id}/block`),
  removeDevice: (id: string) => api.delete(`/api/admin/data/devices/${id}`),
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
  add: (data: { fullName: string; phone: string; role: string; branchId?: string; password?: string }) =>
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
