import { useState, useEffect, useCallback } from 'react';
import { ShieldCheck, Check, X, RefreshCw } from 'lucide-react';
import { PageHeader } from '../components/layout/PageHeader';
import { RoleBadge, ActiveBadge } from '../components/ui/Badges';
import { EmployeeAvatar } from '../components/ui/Timeline';
import { LoadingSkeleton } from '../components/ui/LoadingSkeleton';
import { adminDataApi } from '../services/api';
import type { Role, UserBusinessAssignment } from '../types';

const ROLES: Role[] = ['OWNER', 'MANAGER', 'CASHIER', 'WAITER'];

const PERMISSIONS = [
  { label: 'Verify Payments',      owner: true,  manager: true,  cashier: true,  waiter: true  },
  { label: 'View Transactions',    owner: true,  manager: true,  cashier: true,  waiter: false },
  { label: 'Add Staff',            owner: true,  manager: false, cashier: false, waiter: false },
  { label: 'Remove Staff',         owner: true,  manager: false, cashier: false, waiter: false },
  { label: 'Manage Branches',      owner: true,  manager: false, cashier: false, waiter: false },
  { label: 'Manage Payment Accts', owner: true,  manager: false, cashier: false, waiter: false },
  { label: 'Export Reports',       owner: true,  manager: true,  cashier: true,  waiter: false },
  { label: 'View Fraud Alerts',    owner: true,  manager: true,  cashier: false, waiter: false },
  { label: 'Manage Settings',      owner: true,  manager: false, cashier: false, waiter: false },
];

const ROLE_KEYS: Record<Role, keyof (typeof PERMISSIONS)[0]> = {
  OWNER: 'owner', MANAGER: 'manager', CASHIER: 'cashier', WAITER: 'waiter',
};

export default function RolesPage() {
  const [staff, setStaff] = useState<UserBusinessAssignment[]>([]);
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    setLoading(true);
    try { const res = await adminDataApi.staff(); setStaff(res.data); } catch { /* ignore */ }
    finally { setLoading(false); }
  }, []);

  useEffect(() => { load(); }, [load]);

  return (
    <div className="p-4 md:p-6 space-y-6">
      <PageHeader title="Users & Roles" subtitle="Role-based access control"
        actions={<button onClick={load} className="p-2 rounded-xl text-slate-400 hover:text-white hover:bg-slate-800 transition-colors"><RefreshCw size={16} /></button>} />

      {/* Role summary cards */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        {ROLES.map(role => {
          const count = staff.filter(s => s.role === role).length;
          const perms = PERMISSIONS.filter(p => p[ROLE_KEYS[role]]).length;
          return (
            <div key={role} className="bg-card rounded-2xl border border-slate-800 p-4">
              <div className="flex items-center gap-2 mb-3">
                <div className="w-8 h-8 rounded-xl flex items-center justify-center" style={{ background: 'rgba(184,255,59,0.12)' }}>
                  <ShieldCheck size={15} className="text-[#B8FF3B]" />
                </div>
                <RoleBadge role={role} />
              </div>
              <p className="text-white text-xl font-bold">{loading ? '—' : count}</p>
              <p className="text-slate-500 text-xs">users assigned</p>
              <p className="text-slate-600 text-xs mt-1">{perms} permissions</p>
            </div>
          );
        })}
      </div>

      {/* Permission Matrix */}
      <div className="bg-card rounded-2xl border border-slate-800 overflow-hidden">
        <div className="px-5 py-4 border-b border-slate-800">
          <h3 className="text-white font-semibold text-sm">Permission Matrix</h3>
          <p className="text-slate-500 text-xs mt-0.5">Permissions are fixed per role</p>
        </div>
        <div className="overflow-x-auto scrollbar-thin">
          <table className="w-full text-sm">
            <thead className="bg-slate-900/80">
              <tr>
                <th className="px-4 py-3 text-left text-xs font-semibold text-slate-400 uppercase tracking-wider">Permission</th>
                {ROLES.map(r => <th key={r} className="px-4 py-3 text-center"><RoleBadge role={r} /></th>)}
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-800">
              {PERMISSIONS.map(perm => (
                <tr key={perm.label} className="hover:bg-slate-800/20">
                  <td className="px-4 py-3 text-slate-300 text-sm">{perm.label}</td>
                  {ROLES.map(role => (
                    <td key={role} className="px-4 py-3 text-center">
                      {perm[ROLE_KEYS[role]]
                        ? <Check size={16} className="text-[#B8FF3B] mx-auto" />
                        : <X size={16} className="text-slate-700 mx-auto" />}
                    </td>
                  ))}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* User Assignments */}
      <div className="bg-card rounded-2xl border border-slate-800 overflow-hidden">
        <div className="px-5 py-4 border-b border-slate-800">
          <h3 className="text-white font-semibold text-sm">User Assignments</h3>
        </div>
        {loading ? <LoadingSkeleton rows={5} /> : (
          <div className="divide-y divide-slate-800">
            {staff.map(s => (
              <div key={s.id} className="flex items-center gap-4 px-5 py-3 hover:bg-slate-800/30 transition-colors">
                <EmployeeAvatar name={s.user?.fullName} id={s.userId} />
                <div className="flex-1 min-w-0">
                  <p className="text-white text-sm font-medium">{s.user?.fullName ?? '—'}</p>
                  <p className="text-slate-500 text-xs">{s.user?.phone}</p>
                </div>
                <RoleBadge role={s.role} />
                <span className="text-slate-500 text-xs hidden md:block">{s.branch?.name ?? 'All Branches'}</span>
                <ActiveBadge active={s.status === 'active'} />
              </div>
            ))}
            {staff.length === 0 && <p className="text-slate-500 text-sm text-center py-8">No staff members found.</p>}
          </div>
        )}
      </div>
    </div>
  );
}
