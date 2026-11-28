import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { AuthProvider, useAuth } from './admin/hooks/useAuth';
import { AdminLayout } from './admin/components/layout/AdminLayout';
import { PageLoader } from './admin/components/ui/LoadingSkeleton';
import type { AdminRole } from './admin/types';

import LoginPage           from './admin/pages/LoginPage';
import ForgotPasswordPage  from './admin/pages/ForgotPasswordPage';
import ResetPasswordPage   from './admin/pages/ResetPasswordPage';
import DashboardPage       from './admin/pages/DashboardPage';
import TransactionsPage    from './admin/pages/TransactionsPage';
import LiveMonitorPage     from './admin/pages/LiveMonitorPage';
import FraudCenterPage     from './admin/pages/FraudCenterPage';
import EmployeesPage       from './admin/pages/EmployeesPage';
import BranchesPage        from './admin/pages/BranchesPage';
import ProvidersPage       from './admin/pages/ProvidersPage';
import OcrPage             from './admin/pages/OcrPage';
import ReportsPage         from './admin/pages/ReportsPage';
import AnalyticsPage       from './admin/pages/AnalyticsPage';
import AuditLogsPage       from './admin/pages/AuditLogsPage';
import NotificationsPage   from './admin/pages/NotificationsPage';
import BusinessProfilePage from './admin/pages/BusinessProfilePage';
import RolesPage           from './admin/pages/RolesPage';
import SubscriptionPage    from './admin/pages/SubscriptionPage';
import ApiMonitoringPage   from './admin/pages/ApiMonitoringPage';
import DevicesPage         from './admin/pages/DevicesPage';
import LoginHistoryPage    from './admin/pages/LoginHistoryPage';
import SupportPage         from './admin/pages/SupportPage';
import SettingsPage        from './admin/pages/SettingsPage';
import AccountPage         from './admin/pages/AccountPage';
import PlatformOverviewPage      from './admin/pages/PlatformOverviewPage';
import PlatformOrganizationsPage from './admin/pages/PlatformOrganizationsPage';
import PlatformUsersPage         from './admin/pages/PlatformUsersPage';
import PlatformTransactionsPage  from './admin/pages/PlatformTransactionsPage';
import PlatformSubscriptionsPage from './admin/pages/PlatformSubscriptionsPage';
import PlatformPlansPage        from './admin/pages/PlatformPlansPage';
import PlatformActivityPage      from './admin/pages/PlatformActivityPage';

function DashboardRoute() {
  const { role } = useAuth();
  return role === 'SUPER_ADMIN' ? <PlatformOverviewPage /> : <DashboardPage />;
}

function ProtectedRoute({ children, allowedRoles }: { children: React.ReactNode; allowedRoles?: AdminRole[] }) {
  const { isAuthenticated, isLoading, role } = useAuth();
  if (isLoading) return <PageLoader />;
  if (!isAuthenticated) return <Navigate to="/login" replace />;
  if (allowedRoles && (!role || !allowedRoles.includes(role))) return <Navigate to="/admin" replace />;
  return <AdminLayout>{children}</AdminLayout>;
}

function PublicRoute({ children }: { children: React.ReactNode }) {
  const { isAuthenticated, isLoading } = useAuth();
  if (isLoading) return <PageLoader />;
  if (isAuthenticated) return <Navigate to="/admin" replace />;
  return <>{children}</>;
}

function AppRoutes() {
  return (
    <Routes>
      <Route path="/login" element={<PublicRoute><LoginPage /></PublicRoute>} />
      <Route path="/forgot-password" element={<PublicRoute><ForgotPasswordPage /></PublicRoute>} />
      <Route path="/reset-password" element={<PublicRoute><ResetPasswordPage /></PublicRoute>} />

      <Route path="/admin"                element={<ProtectedRoute><DashboardRoute /></ProtectedRoute>} />
      <Route path="/admin/transactions"   element={<ProtectedRoute><TransactionsPage /></ProtectedRoute>} />
      <Route path="/admin/live"           element={<ProtectedRoute><LiveMonitorPage /></ProtectedRoute>} />
      <Route path="/admin/fraud"          element={<ProtectedRoute><FraudCenterPage /></ProtectedRoute>} />
      <Route path="/admin/employees"      element={<ProtectedRoute><EmployeesPage /></ProtectedRoute>} />
      <Route path="/admin/branches"       element={<ProtectedRoute><BranchesPage /></ProtectedRoute>} />
      <Route path="/admin/providers"      element={<ProtectedRoute><ProvidersPage /></ProtectedRoute>} />
      <Route path="/admin/ocr"            element={<ProtectedRoute><OcrPage /></ProtectedRoute>} />
      <Route path="/admin/reports"        element={<ProtectedRoute><ReportsPage /></ProtectedRoute>} />
      <Route path="/admin/analytics"      element={<ProtectedRoute><AnalyticsPage /></ProtectedRoute>} />
      <Route path="/admin/audit"          element={<ProtectedRoute><AuditLogsPage /></ProtectedRoute>} />
      <Route path="/admin/notifications"  element={<ProtectedRoute><NotificationsPage /></ProtectedRoute>} />
      <Route path="/admin/profile"        element={<ProtectedRoute><BusinessProfilePage /></ProtectedRoute>} />
      <Route path="/admin/roles"          element={<ProtectedRoute><RolesPage /></ProtectedRoute>} />
      <Route path="/admin/subscription"   element={<ProtectedRoute><SubscriptionPage /></ProtectedRoute>} />
      <Route path="/admin/api"            element={<ProtectedRoute><ApiMonitoringPage /></ProtectedRoute>} />
      <Route path="/admin/devices"        element={<ProtectedRoute><DevicesPage /></ProtectedRoute>} />
      <Route path="/admin/login-history"  element={<ProtectedRoute><LoginHistoryPage /></ProtectedRoute>} />
      <Route path="/admin/support"        element={<ProtectedRoute><SupportPage /></ProtectedRoute>} />
      <Route path="/admin/settings"       element={<ProtectedRoute><SettingsPage /></ProtectedRoute>} />
      <Route path="/admin/account"        element={<ProtectedRoute><AccountPage /></ProtectedRoute>} />

      <Route path="/admin/organizations"  element={<ProtectedRoute allowedRoles={['SUPER_ADMIN']}><PlatformOrganizationsPage /></ProtectedRoute>} />
      <Route path="/admin/users"          element={<ProtectedRoute allowedRoles={['SUPER_ADMIN']}><PlatformUsersPage /></ProtectedRoute>} />
      <Route path="/admin/platform/transactions"   element={<ProtectedRoute allowedRoles={['SUPER_ADMIN']}><PlatformTransactionsPage /></ProtectedRoute>} />
      <Route path="/admin/platform/subscriptions"  element={<ProtectedRoute allowedRoles={['SUPER_ADMIN']}><PlatformSubscriptionsPage /></ProtectedRoute>} />
      <Route path="/admin/platform/plans"          element={<ProtectedRoute allowedRoles={['SUPER_ADMIN']}><PlatformPlansPage /></ProtectedRoute>} />
      <Route path="/admin/platform/activity"       element={<ProtectedRoute allowedRoles={['SUPER_ADMIN']}><PlatformActivityPage /></ProtectedRoute>} />

      <Route path="/" element={<Navigate to="/admin" replace />} />
      <Route path="*" element={<Navigate to="/admin" replace />} />
    </Routes>
  );
}

export default function App() {
  return (
    <BrowserRouter>
      <AuthProvider>
        <AppRoutes />
      </AuthProvider>
    </BrowserRouter>
  );
}
