import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { AuthProvider, useAuth } from './admin/hooks/useAuth';
import { AdminLayout } from './admin/components/layout/AdminLayout';
import { PageLoader } from './admin/components/ui/LoadingSkeleton';

import LoginPage           from './admin/pages/LoginPage';
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

function ProtectedRoute({ children }: { children: React.ReactNode }) {
  const { isAuthenticated, isLoading } = useAuth();
  if (isLoading) return <PageLoader />;
  if (!isAuthenticated) return <Navigate to="/login" replace />;
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

      <Route path="/admin"                element={<ProtectedRoute><DashboardPage /></ProtectedRoute>} />
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
