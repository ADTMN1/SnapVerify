import { useState, useEffect, useCallback } from 'react';
import { Activity, CheckCircle, XCircle, Clock, Wifi, RefreshCw } from 'lucide-react';
import { StatusBadge, ActiveBadge } from '../components/ui/Badges';
import { EmployeeAvatar } from '../components/ui/Timeline';
import { formatCurrency, formatRelative } from '../utils';
import { adminDashboardApi, adminDataApi } from '../services/api';
import type { Payment, UserBusinessAssignment } from '../types';
import type { DashboardStats } from '../services/api';

export default function LiveMonitorPage() {
  const [payments, setPayments] = useState<Payment[]>([]);
  const [staff, setStaff] = useState<UserBusinessAssignment[]>([]);
  const [stats, setStats] = useState<DashboardStats | null>(null);
  const [tick, setTick] = useState(0);

  const load = useCallback(async () => {
    try {
      const [p, s, st] = await Promise.all([
        adminDashboardApi.payments(10),
        adminDataApi.staff(),
        adminDashboardApi.stats(),
      ]);
      setPayments(p.data);
      setStaff(s.data);
      setStats(st.data);
      setTick(n => n + 1);
    } catch { /* ignore */ }
  }, []);

  useEffect(() => {
    load();
    const t = setInterval(load, 5000);
    return () => clearInterval(t);
  }, [load]);

  return (
    <div className="p-4 md:p-6 space-y-6">
      <div className="flex items-center gap-3">
        <div className="w-2 h-2 rounded-full bg-[#B8FF3B] animate-pulse" />
        <h1 className="text-white text-xl font-bold">Live Monitor</h1>
        <span className="text-slate-500 text-xs ml-auto">Tick #{tick} · auto-refresh 5s</span>
        <button onClick={load} className="p-1.5 rounded-lg text-slate-400 hover:text-white hover:bg-slate-800 transition-colors"><RefreshCw size={15} /></button>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        {[
          { label: 'Pending', value: stats?.totalPending ?? 0, color: '#fbbf24', icon: <Clock size={18} /> },
          { label: 'Verified Today', value: stats?.todayTransactions ?? 0, color: '#B8FF3B', icon: <CheckCircle size={18} /> },
          { label: 'Fraud Alerts', value: stats?.fraudAlerts ?? 0, color: '#ef4444', icon: <XCircle size={18} /> },
          { label: 'Staff Active', value: staff.filter(s => s.status === 'active').length, color: '#0ea5e9', icon: <Wifi size={18} /> },
        ].map(s => (
          <div key={s.label} className="bg-card rounded-2xl p-4 border border-slate-800 flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl flex items-center justify-center flex-shrink-0" style={{ background: `${s.color}20`, color: s.color }}>{s.icon}</div>
            <div>
              <p className="text-white text-xl font-bold">{s.value}</p>
              <p className="text-slate-500 text-xs">{s.label}</p>
            </div>
          </div>
        ))}
      </div>

      <div className="bg-card rounded-2xl border border-slate-800 overflow-hidden">
        <div className="px-5 py-4 border-b border-slate-800 flex items-center gap-2">
          <Activity size={16} className="text-[#B8FF3B]" />
          <h3 className="text-white font-semibold text-sm">Live Feed</h3>
        </div>
        <div className="divide-y divide-slate-800">
          {payments.length === 0 && (
            <p className="text-slate-500 text-sm text-center py-10">No recent transactions.</p>
          )}
          {payments.map(p => (
            <div key={p.id} className="flex items-center gap-4 px-5 py-3 hover:bg-slate-800/30 transition-colors">
              <EmployeeAvatar name={p.user?.fullName} id={p.userId ?? ''} size="sm" />
              <div className="flex-1 min-w-0">
                <p className="text-white text-sm font-medium truncate">{p.senderName ?? 'Unknown'}</p>
                <p className="text-slate-500 text-xs font-mono">{p.transactionId}</p>
              </div>
              <span className="text-[#B8FF3B] font-semibold text-sm">{formatCurrency(p.amount)}</span>
              <StatusBadge status={p.status} />
              <span className="text-slate-600 text-xs hidden lg:block">{formatRelative(p.createdAt)}</span>
            </div>
          ))}
        </div>
      </div>

      <div className="bg-card rounded-2xl border border-slate-800 p-5">
        <h3 className="text-white font-semibold text-sm mb-4">Staff Status</h3>
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
          {staff.map(s => (
            <div key={s.id} className="flex items-center gap-3 bg-slate-900 rounded-xl p-3">
              <EmployeeAvatar name={s.user?.fullName} id={s.userId} />
              <div className="flex-1 min-w-0">
                <p className="text-white text-sm font-medium truncate">{s.user?.fullName ?? '—'}</p>
                <p className="text-slate-500 text-xs">{s.branch?.name ?? 'No branch'}</p>
              </div>
              <ActiveBadge active={s.status === 'active'} />
            </div>
          ))}
          {staff.length === 0 && <p className="text-slate-500 text-sm col-span-3 text-center py-4">No staff members.</p>}
        </div>
      </div>
    </div>
  );
}
