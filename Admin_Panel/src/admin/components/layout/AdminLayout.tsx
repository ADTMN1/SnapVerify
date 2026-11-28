import { useState, useEffect, type ReactNode } from 'react';
import { NavLink, useNavigate } from 'react-router-dom';
import {
  LayoutDashboard, Receipt, Activity, ShieldAlert, Users, Building2,
  CreditCard, ScanLine, BarChart3, TrendingUp, ClipboardList, Smartphone,
  Bell, Building, ShieldCheck, Zap, Webhook, History, LifeBuoy, Settings,
  Menu, X, ChevronRight, LogOut, User, Sun, Moon,
} from 'lucide-react';
import { useAuth } from '../../hooks/useAuth';

const ICON_MAP: Record<string, React.ElementType> = {
  LayoutDashboard, Receipt, Activity, ShieldAlert, Users, Building2,
  CreditCard, ScanLine, BarChart3, TrendingUp, ClipboardList, Smartphone,
  Bell, Building, ShieldCheck, Zap, Webhook, History, LifeBuoy, Settings, User,
};

const OWNER_NAV = [
  { label: 'Dashboard',        icon: 'LayoutDashboard', path: '/admin' },
  { label: 'Transactions',     icon: 'Receipt',         path: '/admin/transactions' },
  { label: 'Live Monitor',     icon: 'Activity',        path: '/admin/live' },
  { label: 'Fraud Center',     icon: 'ShieldAlert',     path: '/admin/fraud' },
  { label: 'Employees',        icon: 'Users',           path: '/admin/employees' },
  { label: 'Branches',         icon: 'Building2',       path: '/admin/branches' },
  { label: 'Payment Providers',icon: 'CreditCard',      path: '/admin/providers' },
  { label: 'OCR Verification', icon: 'ScanLine',        path: '/admin/ocr' },
  { label: 'Reports',          icon: 'BarChart3',       path: '/admin/reports' },
  { label: 'Analytics',        icon: 'TrendingUp',      path: '/admin/analytics' },
  { label: 'Audit Logs',       icon: 'ClipboardList',   path: '/admin/audit' },
  { label: 'Devices',          icon: 'Smartphone',      path: '/admin/devices' },
  { label: 'Notifications',    icon: 'Bell',            path: '/admin/notifications' },
  { label: 'Business Profile', icon: 'Building',        path: '/admin/profile' },
  { label: 'Users & Roles',    icon: 'ShieldCheck',     path: '/admin/roles' },
  { label: 'Subscription',     icon: 'Zap',             path: '/admin/subscription' },
  { label: 'API Monitoring',   icon: 'Webhook',         path: '/admin/api' },
  { label: 'Login History',    icon: 'History',         path: '/admin/login-history' },
  { label: 'Support',          icon: 'LifeBuoy',        path: '/admin/support' },
  { label: 'My Account',       icon: 'User',            path: '/admin/account' },
  { label: 'Settings',         icon: 'Settings',        path: '/admin/settings' },
];

const PLATFORM_NAV = [
  { label: 'Overview',       icon: 'LayoutDashboard', path: '/admin' },
  { label: 'Organizations',  icon: 'Building2',       path: '/admin/organizations' },
  { label: 'Users',          icon: 'Users',           path: '/admin/users' },
  { label: 'Transactions',   icon: 'Receipt',         path: '/admin/platform/transactions' },
  { label: 'Subscriptions',  icon: 'CreditCard',      path: '/admin/platform/subscriptions' },
  { label: 'Plans',          icon: 'Zap',             path: '/admin/platform/plans' },
  { label: 'Activity',       icon: 'Activity',        path: '/admin/platform/activity' },
  { label: 'Audit Logs',     icon: 'ClipboardList',   path: '/admin/audit' },
  { label: 'Login History',  icon: 'History',         path: '/admin/login-history' },
  { label: 'My Account',     icon: 'User',            path: '/admin/account' },
  { label: 'Settings',       icon: 'Settings',        path: '/admin/settings' },
];

function SidebarContent({ collapsed, onClose }: { collapsed: boolean; onClose?: () => void }) {
  const { user, organization, role, logout } = useAuth();
  const navigate = useNavigate();
  const nav = role === 'SUPER_ADMIN' ? PLATFORM_NAV : OWNER_NAV;
  const [logoutOpen, setLogoutOpen] = useState(false);

  async function handleLogout() {
    setLogoutOpen(false);
    await logout();
    navigate('/login');
  }

  return (
    <div className="flex flex-col h-full">
      {/* Logo */}
      <div className={`flex items-center gap-3 px-4 py-5 border-b border-slate-800 flex-shrink-0 ${collapsed ? 'justify-center' : ''}`}>
        <div className="w-8 h-8 rounded-xl flex items-center justify-center flex-shrink-0" style={{ background: 'linear-gradient(135deg,#B8FF3B,#a3e635)' }}>
          <ShieldCheck size={16} className="text-slate-900" />
        </div>
        {!collapsed && (
          <div className="min-w-0">
            <p className="text-white font-bold text-sm leading-none">SnapVerify</p>
            <p className="text-slate-500 text-xs mt-0.5 truncate">
              {role === 'SUPER_ADMIN' ? 'Platform Admin' : (organization?.name ?? 'Admin Panel')}
            </p>
          </div>
        )}
        {onClose && (
          <button onClick={onClose} className="ml-auto p-1 text-slate-400 hover:text-white lg:hidden">
            <X size={18} />
          </button>
        )}
      </div>

      {/* Nav */}
      <nav className="flex-1 overflow-y-auto py-3 scrollbar-thin px-2">
        {nav.map(item => {
          const Icon = ICON_MAP[item.icon] ?? LayoutDashboard;
          return (
            <NavLink
              key={item.path}
              to={item.path}
              end={item.path === '/admin'}
              onClick={onClose}
              className={({ isActive }) =>
                `flex items-center gap-3 px-3 py-2.5 rounded-xl mb-0.5 text-sm font-medium transition-all group ${
                  isActive
                    ? 'text-slate-900 font-semibold'
                    : 'text-slate-400 hover:text-white hover:bg-slate-800'
                } ${collapsed ? 'justify-center' : ''}`
              }
              style={({ isActive }) => isActive ? { background: '#B8FF3B' } : {}}
              title={collapsed ? item.label : undefined}
            >
              <Icon size={17} className="flex-shrink-0" />
              {!collapsed && <span className="truncate">{item.label}</span>}
            </NavLink>
          );
        })}
      </nav>

      {/* User */}
      <div className={`border-t border-slate-800 p-3 flex-shrink-0 ${collapsed ? 'flex justify-center' : ''}`}>
        {collapsed ? (
          <button onClick={() => setLogoutOpen(true)} className="p-2 rounded-xl text-slate-400 hover:text-red-400 hover:bg-slate-800 transition-colors" title="Logout" aria-label="Logout">
            <LogOut size={17} />
          </button>
        ) : (
          <div className="flex items-center gap-3">
            <div className="w-8 h-8 rounded-xl bg-slate-700 flex items-center justify-center flex-shrink-0">
              <User size={15} className="text-slate-300" />
            </div>
            <div className="flex-1 min-w-0">
              <p className="text-white text-xs font-semibold truncate">{user?.fullName ?? 'Admin'}</p>
              <p className="text-slate-500 text-xs truncate">{user?.phone}</p>
            </div>
            <button onClick={() => setLogoutOpen(true)} className="p-1.5 rounded-lg text-slate-500 hover:text-red-400 hover:bg-slate-800 transition-colors flex-shrink-0" title="Logout" aria-label="Logout">
              <LogOut size={15} />
            </button>
          </div>
        )}
      </div>

      {/* Logout confirmation popout */}
      {logoutOpen && (
        <div className="fixed inset-0 z-[60]" onClick={() => setLogoutOpen(false)}>
          <div
            className="absolute bottom-20 left-3 w-64 bg-card border border-slate-700 rounded-2xl shadow-2xl p-4"
            style={{ marginLeft: collapsed ? '0' : undefined }}
            onClick={e => e.stopPropagation()}
          >
            <div className="flex items-center gap-2 mb-1">
              <LogOut size={16} className="text-red-400" />
              <p className="text-white text-sm font-semibold">Log out?</p>
            </div>
            <p className="text-slate-400 text-xs">You will need to sign in again to access the admin panel.</p>
            <div className="flex gap-2 justify-end mt-4">
              <button onClick={() => setLogoutOpen(false)} className="px-3 py-1.5 rounded-lg text-xs font-medium text-slate-300 hover:text-white hover:bg-slate-800 transition-colors">
                Cancel
              </button>
              <button onClick={handleLogout} className="px-3 py-1.5 rounded-lg text-xs font-semibold text-white transition-colors" style={{ background: '#ef4444' }}>
                Log out
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

export function AdminLayout({ children }: { children: ReactNode }) {
  const [collapsed, setCollapsed] = useState(false);
  const [mobileOpen, setMobileOpen] = useState(false);
  const [theme, setTheme] = useState<'dark' | 'light'>(
    () => (localStorage.getItem('sv_theme') as 'dark' | 'light') || 'dark',
  );

  useEffect(() => {
    const root = document.documentElement;
    if (theme === 'light') root.classList.add('light');
    else root.classList.remove('light');
    localStorage.setItem('sv_theme', theme);
  }, [theme]);

  return (
    <div className="flex h-screen bg-app overflow-hidden">
      {/* Desktop Sidebar */}
      <aside className={`hidden lg:flex flex-col flex-shrink-0 bg-card border-r border-slate-800 transition-all duration-300 ${collapsed ? 'w-16' : 'w-60'}`}>
        <SidebarContent collapsed={collapsed} />
      </aside>

      {/* Mobile Sidebar Overlay */}
      {mobileOpen && (
        <div className="fixed inset-0 z-50 lg:hidden flex">
          <div className="absolute inset-0 bg-black/60 backdrop-blur-sm" onClick={() => setMobileOpen(false)} />
          <aside className="relative w-64 bg-card border-r border-slate-800 flex flex-col z-10">
            <SidebarContent collapsed={false} onClose={() => setMobileOpen(false)} />
          </aside>
        </div>
      )}

      {/* Main */}
      <div className="flex-1 flex flex-col min-w-0 overflow-hidden">
        {/* Topbar */}
        <header className="flex items-center gap-3 px-4 py-3 border-b border-slate-800 bg-card flex-shrink-0">
          <button
            onClick={() => { setCollapsed(c => !c); setMobileOpen(c => !c); }}
            className="p-2 rounded-xl text-slate-400 hover:text-white hover:bg-slate-800 transition-colors"
            aria-label="Toggle sidebar"
          >
            <Menu size={18} />
          </button>
          <div className="flex items-center gap-1 text-slate-500 text-sm">
            <ChevronRight size={14} />
          </div>
          <div className="flex-1" />
          <button
            onClick={() => setTheme(t => (t === 'dark' ? 'light' : 'dark'))}
            className="p-2 rounded-xl text-slate-400 hover:text-white hover:bg-slate-800 transition-colors"
            aria-label="Toggle color theme"
            title={theme === 'dark' ? 'Switch to light mode' : 'Switch to dark mode'}
          >
            {theme === 'dark' ? <Sun size={18} /> : <Moon size={18} />}
          </button>
          <button className="relative p-2 rounded-xl text-slate-400 hover:text-white hover:bg-slate-800 transition-colors">
            <Bell size={18} />
            <span className="absolute top-1.5 right-1.5 w-2 h-2 rounded-full bg-[#B8FF3B]" />
          </button>
        </header>

        {/* Page Content */}
        <main className="flex-1 overflow-y-auto scrollbar-thin">
          {children}
        </main>
      </div>
    </div>
  );
}
