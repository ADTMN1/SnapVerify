import { createContext, useContext, useState, useEffect, useCallback, type ReactNode } from 'react';
import type { AuthState, AuthUser, Organization, Role } from '../types';
import { adminAuthApi, authApi } from '../services/api';

interface AuthContextValue extends AuthState {
  login: (phoneOrEmail: string, password: string, organizationId?: string) => Promise<void>;
  logout: () => Promise<void>;
}

const AuthContext = createContext<AuthContextValue | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState<AuthState>({
    user: null, organization: null, tokens: null, role: null,
    isAuthenticated: false, isLoading: true,
  });

  // Restore session on mount — try admin token first, then regular token
  const restore = useCallback(async () => {
    const adminToken = localStorage.getItem('sv_admin_token');
    const adminRefresh = localStorage.getItem('sv_admin_refresh_token');

    if (adminToken && adminRefresh) {
      try {
        const res = await adminAuthApi.me();
        const admin = res.data as { id: string; fullName?: string; email?: string; phone: string; status: string; createdAt: string; updatedAt: string; organizations: { organizationId: string; role: string }[] };
        const payload = JSON.parse(atob(adminToken.split('.')[1]));
        // Use first organization from assignments
        const firstOrg = admin.organizations[0];
        setState({
          user: { id: admin.id, fullName: admin.fullName, phone: admin.phone, email: admin.email, status: admin.status, createdAt: admin.createdAt, updatedAt: admin.updatedAt },
          organization: firstOrg ? { id: firstOrg.organizationId, name: '', type: '', phone: admin.phone, status: 'active', createdAt: admin.createdAt, updatedAt: admin.updatedAt } : null,
          tokens: { accessToken: adminToken, refreshToken: adminRefresh },
          role: payload.role as Role,
          isAuthenticated: true,
          isLoading: false,
        });
        return;
      } catch {
        localStorage.removeItem('sv_admin_token');
        localStorage.removeItem('sv_admin_refresh_token');
      }
    }

    // Fallback: regular user token
    const accessToken = localStorage.getItem('sv_access_token');
    const refreshToken = localStorage.getItem('sv_refresh_token');
    if (accessToken && refreshToken) {
      try {
        const res = await authApi.me();
        const { user, organization } = res.data as { user: AuthUser; organization: Organization };
        const payload = JSON.parse(atob(accessToken.split('.')[1]));
        setState({ user, organization, tokens: { accessToken, refreshToken }, role: payload.role as Role, isAuthenticated: true, isLoading: false });
        return;
      } catch {
        localStorage.removeItem('sv_access_token');
        localStorage.removeItem('sv_refresh_token');
      }
    }

    setState(s => ({ ...s, isLoading: false }));
  }, []);

  useEffect(() => { restore(); }, [restore]);

  const login = useCallback(async (phoneOrEmail: string, password: string, organizationId?: string) => {
    // Detect if input is email (contains @) → use admin auth
    const isEmail = phoneOrEmail.includes('@');

    if (isEmail) {
      // Admin login via email
      let res;
      try {
        res = await adminAuthApi.login(phoneOrEmail, password);
      } catch (err: unknown) {
        const axiosErr = err as { response?: { data?: { message?: string | string[] } } };
        const msg = axiosErr.response?.data?.message;
        throw new Error(Array.isArray(msg) ? msg.join(', ') : (msg ?? 'Login failed'));
      }
      const { tokens, admin, organizations } = res.data as {
        tokens: { accessToken: string; refreshToken: string };
        admin: AuthUser & { email?: string };
        organizations: { organizationId: string; role: string }[];
      };
      localStorage.setItem('sv_admin_token', tokens.accessToken);
      localStorage.setItem('sv_admin_refresh_token', tokens.refreshToken);
      const payload = JSON.parse(atob(tokens.accessToken.split('.')[1]));
      const firstOrg = organizations[0];
      setState({
        user: admin,
        organization: firstOrg ? { id: firstOrg.organizationId, name: '', type: '', phone: admin.phone, status: 'active', createdAt: admin.createdAt, updatedAt: admin.updatedAt } : null,
        tokens,
        role: payload.role as Role,
        isAuthenticated: true,
        isLoading: false,
      });
    } else {
      // Phone login — regular user auth, needed for owners logging in by phone
      let res;
      try {
        res = await authApi.login(phoneOrEmail, password, organizationId);
      } catch (err: unknown) {
        const axiosErr = err as { response?: { data?: { message?: string | string[] } } };
        const msg = axiosErr.response?.data?.message;
        throw new Error(Array.isArray(msg) ? msg.join(', ') : (msg ?? 'Login failed'));
      }
      const { tokens, user, organization } = res.data as {
        tokens: { accessToken: string; refreshToken: string };
        user: AuthUser;
        organization: Organization;
      };
      // Store as admin token so dashboard endpoints work (admin guard uses same JWT secret)
      localStorage.setItem('sv_admin_token', tokens.accessToken);
      localStorage.setItem('sv_admin_refresh_token', tokens.refreshToken);
      localStorage.setItem('sv_access_token', tokens.accessToken);
      localStorage.setItem('sv_refresh_token', tokens.refreshToken);
      const payload = JSON.parse(atob(tokens.accessToken.split('.')[1]));
      setState({ user, organization, tokens, role: payload.role as Role, isAuthenticated: true, isLoading: false });
    }
  }, []);

  const logout = useCallback(async () => {
    const adminRefresh = localStorage.getItem('sv_admin_refresh_token');
    const regularRefresh = localStorage.getItem('sv_refresh_token');
    try {
      if (adminRefresh) await adminAuthApi.logout(adminRefresh);
      else if (regularRefresh) await authApi.logout(regularRefresh);
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
