import type { Payment, Branch, UserBusinessAssignment, ActivityLog, VerificationLog, Device } from '../types';

export const mockBranches: Branch[] = [
  { id: 'b1', organizationId: 'org1', name: 'Main Branch', address: 'Bole, Addis Ababa', phone: '0911000001', createdAt: '2026-01-01T00:00:00Z', updatedAt: '2026-01-01T00:00:00Z' },
  { id: 'b2', organizationId: 'org1', name: 'Kazanchis Branch', address: 'Kazanchis, Addis Ababa', phone: '0911000002', createdAt: '2026-01-15T00:00:00Z', updatedAt: '2026-01-15T00:00:00Z' },
  { id: 'b3', organizationId: 'org1', name: 'Piassa Branch', address: 'Piassa, Addis Ababa', phone: '0911000003', createdAt: '2026-02-01T00:00:00Z', updatedAt: '2026-02-01T00:00:00Z' },
];

export const mockStaff: UserBusinessAssignment[] = [
  { id: 'a1', userId: 'u1', organizationId: 'org1', branchId: 'b1', role: 'CASHIER', status: 'active', createdAt: '2026-01-05T00:00:00Z', updatedAt: '2026-07-01T00:00:00Z', user: { id: 'u1', fullName: 'Abebe Kebede', phone: '0911111111', status: 'active', createdAt: '2026-01-05T00:00:00Z', updatedAt: '2026-07-01T00:00:00Z' }, branch: mockBranches[0] },
  { id: 'a2', userId: 'u2', organizationId: 'org1', branchId: 'b1', role: 'WAITER',  status: 'active', createdAt: '2026-01-10T00:00:00Z', updatedAt: '2026-07-01T00:00:00Z', user: { id: 'u2', fullName: 'Tigist Alemu', phone: '0922222222', status: 'active', createdAt: '2026-01-10T00:00:00Z', updatedAt: '2026-07-01T00:00:00Z' }, branch: mockBranches[0] },
  { id: 'a3', userId: 'u3', organizationId: 'org1', branchId: 'b2', role: 'MANAGER', status: 'active', createdAt: '2026-01-20T00:00:00Z', updatedAt: '2026-07-01T00:00:00Z', user: { id: 'u3', fullName: 'Dawit Haile', phone: '0933333333', status: 'active', createdAt: '2026-01-20T00:00:00Z', updatedAt: '2026-07-01T00:00:00Z' }, branch: mockBranches[1] },
  { id: 'a4', userId: 'u4', organizationId: 'org1', branchId: 'b2', role: 'CASHIER', status: 'active', createdAt: '2026-02-01T00:00:00Z', updatedAt: '2026-07-01T00:00:00Z', user: { id: 'u4', fullName: 'Meron Tadesse', phone: '0944444444', status: 'active', createdAt: '2026-02-01T00:00:00Z', updatedAt: '2026-07-01T00:00:00Z' }, branch: mockBranches[1] },
  { id: 'a5', userId: 'u5', organizationId: 'org1', branchId: 'b3', role: 'CASHIER', status: 'inactive', createdAt: '2026-03-01T00:00:00Z', updatedAt: '2026-07-01T00:00:00Z', user: { id: 'u5', fullName: 'Yonas Girma', phone: '0955555555', status: 'inactive', createdAt: '2026-03-01T00:00:00Z', updatedAt: '2026-07-01T00:00:00Z' }, branch: mockBranches[2] },
];

export const mockPayments: Payment[] = [
  { id: 'p1', organizationId: 'org1', userId: 'u1', amount: 1500, currency: 'ETB', paymentMethod: 'REFERENCE', transactionId: 'FT2607230001', senderName: 'Kebede Alemu', receiverName: 'SnapVerify Restaurant', status: 'VERIFIED', riskScore: 0, createdAt: '2026-07-23T08:15:00Z', updatedAt: '2026-07-23T08:15:00Z', user: mockStaff[0].user },
  { id: 'p2', organizationId: 'org1', userId: 'u2', amount: 850, currency: 'ETB', paymentMethod: 'IMAGE_OCR', transactionId: 'FT2607230002', senderName: 'Tigist Bekele', receiverName: 'SnapVerify Restaurant', status: 'VERIFIED', riskScore: 5, createdAt: '2026-07-23T09:30:00Z', updatedAt: '2026-07-23T09:30:00Z', user: mockStaff[1].user },
  { id: 'p3', organizationId: 'org1', userId: 'u3', amount: 3200, currency: 'ETB', paymentMethod: 'REFERENCE', transactionId: 'FT2607230003', senderName: 'Dawit Haile', receiverName: 'SnapVerify Restaurant', status: 'REJECTED', riskScore: 85, createdAt: '2026-07-23T10:00:00Z', updatedAt: '2026-07-23T10:00:00Z', user: mockStaff[2].user },
  { id: 'p4', organizationId: 'org1', userId: 'u1', amount: 500, currency: 'ETB', paymentMethod: 'IMAGE_OCR', transactionId: 'FT2607230004', senderName: 'Meron Tadesse', receiverName: 'SnapVerify Restaurant', status: 'PENDING', riskScore: 20, createdAt: '2026-07-23T10:45:00Z', updatedAt: '2026-07-23T10:45:00Z', user: mockStaff[0].user },
  { id: 'p5', organizationId: 'org1', userId: 'u4', amount: 2100, currency: 'ETB', paymentMethod: 'REFERENCE', transactionId: 'FT2607230005', senderName: 'Yonas Girma', receiverName: 'SnapVerify Restaurant', status: 'VERIFIED', riskScore: 0, createdAt: '2026-07-23T11:20:00Z', updatedAt: '2026-07-23T11:20:00Z', user: mockStaff[3].user },
  { id: 'p6', organizationId: 'org1', userId: 'u2', amount: 750, currency: 'ETB', paymentMethod: 'IMAGE_OCR', transactionId: 'FT2607230006', senderName: 'Hana Bekele', receiverName: 'SnapVerify Restaurant', status: 'FAILED', riskScore: 90, createdAt: '2026-07-23T12:00:00Z', updatedAt: '2026-07-23T12:00:00Z', user: mockStaff[1].user },
  { id: 'p7', organizationId: 'org1', userId: 'u3', amount: 4500, currency: 'ETB', paymentMethod: 'REFERENCE', transactionId: 'FT2607230007', senderName: 'Solomon Tesfaye', receiverName: 'SnapVerify Restaurant', status: 'VERIFIED', riskScore: 0, createdAt: '2026-07-23T13:10:00Z', updatedAt: '2026-07-23T13:10:00Z', user: mockStaff[2].user },
  { id: 'p8', organizationId: 'org1', userId: 'u1', amount: 1200, currency: 'ETB', paymentMethod: 'REFERENCE', transactionId: 'FT2607230008', senderName: 'Rahel Hailu', receiverName: 'SnapVerify Restaurant', status: 'VERIFIED', riskScore: 10, createdAt: '2026-07-23T14:00:00Z', updatedAt: '2026-07-23T14:00:00Z', user: mockStaff[0].user },
];

export const mockVerificationLogs: VerificationLog[] = [
  { id: 'vl1', organizationId: 'org1', paymentId: 'p1', userId: 'u1', action: 'VERIFIED', reason: 'Payment verified successfully', riskScore: 0, matchedProvider: 'CBE', matchedSuffix: '12345678', createdAt: '2026-07-23T08:15:05Z' },
  { id: 'vl2', organizationId: 'org1', paymentId: 'p3', userId: 'u3', action: 'REJECTED', reason: 'Payment sent to different account', riskScore: 85, matchedProvider: 'TELEBIRR', createdAt: '2026-07-23T10:00:05Z' },
  { id: 'vl3', organizationId: 'org1', paymentId: 'p6', userId: 'u2', action: 'REJECTED', reason: 'Edited screenshot detected', riskScore: 90, createdAt: '2026-07-23T12:00:05Z' },
];

export const mockActivityLogs: ActivityLog[] = [
  { id: 'al1', organizationId: 'org1', userId: 'u1', action: 'PAYMENT_VERIFIED', metadata: { paymentId: 'p1', amount: 1500 }, ipAddress: '192.168.1.10', createdAt: '2026-07-23T08:15:05Z', user: mockStaff[0].user },
  { id: 'al2', organizationId: 'org1', userId: 'u3', action: 'PAYMENT_REJECTED', metadata: { paymentId: 'p3', reason: 'Wrong account' }, ipAddress: '192.168.1.12', createdAt: '2026-07-23T10:00:05Z', user: mockStaff[2].user },
  { id: 'al3', organizationId: 'org1', userId: 'u1', action: 'LOGIN', metadata: { device: 'Android' }, ipAddress: '192.168.1.10', createdAt: '2026-07-23T08:00:00Z', user: mockStaff[0].user },
  { id: 'al4', organizationId: 'org1', userId: 'u2', action: 'PAYMENT_VERIFIED', metadata: { paymentId: 'p2', amount: 850 }, ipAddress: '192.168.1.11', createdAt: '2026-07-23T09:30:05Z', user: mockStaff[1].user },
];

export const mockDevices: Device[] = [
  { id: 'd1', userAssignmentId: 'a1', deviceFingerprint: 'fp_abc123', deviceName: 'Samsung Galaxy A54', isActive: true, lastLoginAt: '2026-07-23T08:00:00Z', createdAt: '2026-01-05T00:00:00Z', userAssignment: mockStaff[0] },
  { id: 'd2', userAssignmentId: 'a2', deviceFingerprint: 'fp_def456', deviceName: 'Tecno Camon 20', isActive: true, lastLoginAt: '2026-07-23T09:00:00Z', createdAt: '2026-01-10T00:00:00Z', userAssignment: mockStaff[1] },
  { id: 'd3', userAssignmentId: 'a3', deviceFingerprint: 'fp_ghi789', deviceName: 'iPhone 14', isActive: false, lastLoginAt: '2026-07-20T14:00:00Z', createdAt: '2026-01-20T00:00:00Z', userAssignment: mockStaff[2] },
];

export const mockRevenueChart = [
  { date: '2026-07-17', value: 12400 },
  { date: '2026-07-18', value: 18200 },
  { date: '2026-07-19', value: 9800 },
  { date: '2026-07-20', value: 22100 },
  { date: '2026-07-21', value: 15600 },
  { date: '2026-07-22', value: 28900 },
  { date: '2026-07-23', value: 14550 },
];

export const mockVerificationTrend = [
  { date: '2026-07-17', verified: 45, rejected: 3, failed: 2 },
  { date: '2026-07-18', verified: 62, rejected: 5, failed: 1 },
  { date: '2026-07-19', verified: 38, rejected: 2, failed: 3 },
  { date: '2026-07-20', verified: 71, rejected: 8, failed: 2 },
  { date: '2026-07-21', verified: 55, rejected: 4, failed: 1 },
  { date: '2026-07-22', verified: 89, rejected: 6, failed: 4 },
  { date: '2026-07-23', verified: 34, rejected: 3, failed: 1 },
];

export const mockProviderStats = [
  { provider: 'CBE',       count: 142, amount: 285400 },
  { provider: 'TELEBIRR',  count: 98,  amount: 156800 },
  { provider: 'DASHEN',    count: 45,  amount: 89200  },
  { provider: 'ABYSSINIA', count: 32,  amount: 64100  },
  { provider: 'CBEBIRR',   count: 28,  amount: 42300  },
  { provider: 'M_PESA',    count: 12,  amount: 18600  },
];

export const mockBranchPerformance = [
  { name: 'Main Branch',      verified: 145, revenue: 289000, fraud: 2 },
  { name: 'Kazanchis Branch', verified: 98,  revenue: 196000, fraud: 5 },
  { name: 'Piassa Branch',    verified: 71,  revenue: 142000, fraud: 1 },
];

export const mockDashboardStats = {
  totalVerified: 357,
  totalPending: 12,
  totalFailed: 8,
  fraudAlerts: 3,
  todayRevenue: 14550,
  todayTransactions: 38,
  activeEmployees: 4,
  activeBranches: 3,
};
