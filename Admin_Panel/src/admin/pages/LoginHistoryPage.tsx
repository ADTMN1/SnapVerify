import { useState, useEffect, useCallback } from 'react';
import { LogIn, LogOut, AlertTriangle, RefreshCw } from 'lucide-react';
import { PageHeader } from '../components/layout/PageHeader';
import { Btn } from '../components/layout/PageHeader';
import { EmployeeAvatar } from '../components/ui/Timeline';
import { LoadingSkeleton } from '../components/ui/LoadingSkeleton';
import { formatDateTime, formatRelative } from '../utils';
import { adminDataApi } from '../services/api';
import type { ActivityLog } from '../types';

const TYPE_CONFIG: Record<string, { icon: React.ElementType; color: string; label: string }> = {
  LOGIN:        { icon: LogIn,        color: '#B8FF3B', label: 'Login' },
  ADMIN_LOGIN:  { icon: LogIn,        color: '#a78bfa', label: 'Admin Login' },
  LOGOUT:       { icon: LogOut,       color: '#94a3b8', label: 'Logout' },
  ADMIN_LOGOUT: { icon: LogOut,       color: '#94a3b8', label: 'Admin Logout' },
  LOGIN_FAILED: { icon: AlertTriangle,color: '#ef4444', label: 'Failed' },
};

export default function LoginHistoryPage() {
  const [logs, setLogs] = useState<ActivityLog[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  const load = useCallback(async () => {
    setLoading(true); setError('');
    try {
      const res = await adminDataApi.loginHistory({ page, limit: 50 });
      setLogs(res.data.data);
      setTotal(res.data.total);
    } catch { setError('Failed to load login history'); }
    finally { setLoading(false); }
  }, [page]);

  useEffect(() => { load(); }, [load]);

  const failedCount = logs.filter(l => l.action === 'LOGIN_FAILED').length;

  return (
    <div className="p-4 md:p-6 space-y-6">
      <PageHeader
        title="Login History"
        subtitle={loading ? 'Loading…' : `${total} events`}
        actions={<button onClick={load} className="p-2 rounded-xl text-slate-400 hover:text-white hover:bg-slate-800 transition-colors"><RefreshCw size={16} /></button>}
      />

      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        {[
          { label: 'Total Events', value: total, color: '#0ea5e9' },
          { label: 'Logins', value: logs.filter(l => l.action === 'LOGIN' || l.action === 'ADMIN_LOGIN').length, color: '#B8FF3B' },
          { label: 'Failed', value: failedCount, color: '#ef4444' },
          { label: 'Logouts', value: logs.filter(l => l.action.includes('LOGOUT')).length, color: '#94a3b8' },
        ].map(s => (
          <div key={s.label} className="bg-card rounded-2xl border border-slate-800 p-4">
            <p className="text-2xl font-bold" style={{ color: s.color }}>{s.value}</p>
            <p className="text-slate-500 text-xs mt-1">{s.label}</p>
          </div>
        ))}
      </div>

      {failedCount > 0 && (
        <div className="rounded-2xl p-4 border border-red-500/30 flex items-center gap-3" style={{ background: 'rgba(239,68,68,0.08)' }}>
          <AlertTriangle size={18} className="text-red-400 flex-shrink-0" />
          <p className="text-red-400 text-sm font-medium">{failedCount} failed login attempt{failedCount > 1 ? 's' : ''} detected.</p>
        </div>
      )}

      {error && <p className="text-red-400 text-sm">{error}</p>}

      {loading ? <LoadingSkeleton rows={10} /> : (
        <div className="bg-card rounded-2xl border border-slate-800 overflow-hidden">
          <div className="overflow-x-auto scrollbar-thin">
            <table className="w-full text-sm">
              <thead className="bg-slate-900/80">
                <tr>{['User', 'Event', 'IP Address', 'Time'].map(h => (
                  <th key={h} className="px-4 py-3 text-left text-xs font-semibold text-slate-400 uppercase tracking-wider whitespace-nowrap">{h}</th>
                ))}</tr>
              </thead>
              <tbody className="divide-y divide-slate-800">
                {logs.map(log => {
                  const cfg = TYPE_CONFIG[log.action] ?? { icon: LogIn, color: '#94a3b8', label: log.action };
                  const Icon = cfg.icon;
                  return (
                    <tr key={log.id} className="hover:bg-slate-800/30 transition-colors">
                      <td className="px-4 py-3">
                        <div className="flex items-center gap-2">
                          <EmployeeAvatar name={log.user?.fullName} id={log.userId ?? ''} size="sm" />
                          <span className="text-white text-sm font-medium">{log.user?.fullName ?? 'System'}</span>
                        </div>
                      </td>
                      <td className="px-4 py-3">
                        <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg text-xs font-semibold"
                          style={{ background: `${cfg.color}18`, color: cfg.color }}>
                          <Icon size={12} />{cfg.label}
                        </span>
                      </td>
                      <td className="px-4 py-3 text-slate-400 text-xs font-mono">{log.ipAddress ?? '—'}</td>
                      <td className="px-4 py-3">
                        <p className="text-slate-400 text-xs">{formatDateTime(log.createdAt)}</p>
                        <p className="text-slate-600 text-xs">{formatRelative(log.createdAt)}</p>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
          {logs.length === 0 && <p className="text-slate-500 text-sm text-center py-12">No login events found.</p>}
        </div>
      )}

      {!loading && total > 50 && (
        <div className="flex justify-center gap-2">
          <Btn variant="secondary" size="sm" onClick={() => setPage(p => Math.max(1, p - 1))} disabled={page === 1}>Prev</Btn>
          <span className="text-slate-400 text-sm self-center">Page {page} of {Math.ceil(total / 50)}</span>
          <Btn variant="secondary" size="sm" onClick={() => setPage(p => p + 1)} disabled={page >= Math.ceil(total / 50)}>Next</Btn>
        </div>
      )}
    </div>
  );
}
