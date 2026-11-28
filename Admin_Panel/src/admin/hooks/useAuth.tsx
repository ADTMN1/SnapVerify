import { createContext, useContext, useState, useEffect, useCallback, type ReactNode } from 'react';
import type { AuthState, AuthUser, AdminRole } from '../types';
import { adminAuthApi } from '../services/api';

interface AuthContextValue extends AuthState {
  login: (email: string, password: string) => Promise<void>;
  logout: () => Promise<void>;
}

const AuthContext = createContext<AuthContextValue | null>(null);

function adminRole(
  isPlatformAdmin: boolean | undefined,
  organizations: { role: string }[],
): AdminRole {
  if (isPlatformAdmin) return 'SUPER_ADMIN';
  return organizations.some(o => o.role === 'OWNER')
    ? 'BUSINESS_OWNER'
    : 'OWNER';
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState<AuthState>({
    user: null, organization: null, tokens: null, role: null,
    isAuthenticated: false, isLoading: true,
  });

  const restore = useCallback(async () => {
    const adminToken = localStorage.getItem('sv_admin_token');
    const adminRefresh = localStorage.getItem('sv_admin_refresh_token');

    if (!adminToken || !adminRefresh) {
      localStorage.removeItem('sv_admin_token');
      localStorage.removeItem('sv_admin_refresh_token');
      setState(s => ({ ...s, isLoading: false }));
      return;
    }

    try {
      const res = await adminAuthApi.me();
      const admin = res.data as { id: string; fullName?: string; email?: string; phone: string; status: string; isPlatformAdmin?: boolean; createdAt: string; updatedAt: string; organizations: { organizationId: string; role: string }[] };
      const currentToken = localStorage.getItem('sv_admin_token') ?? adminToken;
      const currentRefresh = localStorage.getItem('sv_admin_refresh_token') ?? adminRefresh;
      const firstOrg = admin.organizations[0];
      setState({
        user: { id: admin.id, fullName: admin.fullName, phone: admin.phone, email: admin.email, status: admin.status, isPlatformAdmin: admin.isPlatformAdmin, createdAt: admin.createdAt, updatedAt: admin.updatedAt },
        organization: firstOrg ? { id: firstOrg.organizationId, name: '', type: '', phone: admin.phone, status: 'active', createdAt: admin.createdAt, updatedAt: admin.updatedAt } : null,
        tokens: { accessToken: currentToken, refreshToken: currentRefresh },
        role: adminRole(admin.isPlatformAdmin, admin.organizations),
        isAuthenticated: true,
        isLoading: false,
      });
    } catch {
      localStorage.removeItem('sv_admin_token');
      localStorage.removeItem('sv_admin_refresh_token');
      setState(s => ({ ...s, isLoading: false }));
    }
  }, []);

  useEffect(() => { restore(); }, [restore]);

  useEffect(() => {
    const clearSession = () => setState({
      user: null, organization: null, tokens: null, role: null,
      isAuthenticated: false, isLoading: false,
    });
    window.addEventListener('sv-admin-session-expired', clearSession);
    return () => window.removeEventListener('sv-admin-session-expired', clearSession);
  }, []);

  const login = useCallback(async (email: string, password: string) => {
    let res;
    try {
      res = await adminAuthApi.login(email, password);
    } catch (err: unknown) {
      const axiosErr = err as { response?: { data?: { message?: string | string[] } } };
      const msg = axiosErr.response?.data?.message;
      throw new Error(
        Array.isArray(msg) ? msg.join(', ') : (msg ?? 'Login failed'),
        { cause: err },
      );
    }
    const { tokens, admin, organizations } = res.data as {
      tokens: { accessToken: string; refreshToken: string };
      admin: AuthUser & { email?: string; isPlatformAdmin?: boolean };
      organizations: { organizationId: string; role: string }[];
    };
    localStorage.setItem('sv_admin_token', tokens.accessToken);
    localStorage.setItem('sv_admin_refresh_token', tokens.refreshToken);
    const firstOrg = organizations[0];
    setState({
      user: admin,
      organization: firstOrg ? { id: firstOrg.organizationId, name: '', type: '', phone: admin.phone, status: 'active', createdAt: admin.createdAt, updatedAt: admin.updatedAt } : null,
      tokens,
      role: adminRole(admin.isPlatformAdmin, organizations),
      isAuthenticated: true,
      isLoading: false,
    });
  }, []);

  const logout = useCallback(async () => {
    const adminRefresh = localStorage.getItem('sv_admin_refresh_token');
    try {
      if (adminRefresh) await adminAuthApi.logout(adminRefresh);
    } catch { /* ignore */ }
    localStorage.removeItem('sv_admin_token');
    localStorage.removeItem('sv_admin_refresh_token');
    localStorage.removeItem('sv_access_token');
    localStorage.removeItem('sv_refresh_token');
    setState({ user: null, organization: null, tokens: null, role: null, isAuthenticated: false, isLoading: false });
  }, []);

  return <AuthContext value={{ ...state, login, logout }}>{children}</AuthContext>;
}

export function useAuth(): AuthContextValue {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be used within AuthProvider');
  return ctx;
}
