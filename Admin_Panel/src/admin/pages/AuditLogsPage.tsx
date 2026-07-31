import { useState, useEffect, useCallback } from 'react';
import { Download, RefreshCw } from 'lucide-react';
import { PageHeader, Btn } from '../components/layout/PageHeader';
import { SearchInput, Select } from '../components/ui/Overlays';
import { EmployeeAvatar } from '../components/ui/Timeline';
import { LoadingSkeleton } from '../components/ui/LoadingSkeleton';
import { formatDateTime, formatRelative } from '../utils';
import { adminDataApi } from '../services/api';
import type { ActivityLog } from '../types';

const ACTION_OPTIONS = [
  { label: 'Payment Verified', value: 'PAYMENT_VERIFIED' },
  { label: 'Payment Rejected', value: 'PAYMENT_REJECTED' },
  { label: 'Login', value: 'LOGIN' },
  { label: 'Logout', value: 'LOGOUT' },
  { label: 'Admin Login', value: 'ADMIN_LOGIN' },
];

const ACTION_COLORS: Record<string, string> = {
  PAYMENT_VERIFIED: '#B8FF3B', PAYMENT_REJECTED: '#ef4444',
  LOGIN: '#0ea5e9', LOGOUT: '#94a3b8', ADMIN_LOGIN: '#a78bfa',
  FRAUD_DETECTED: '#f59e0b', SETTINGS_CHANGED: '#a78bfa',
};

export default function AuditLogsPage() {
  const [logs, setLogs] = useState<ActivityLog[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [search, setSearch] = useState('');
  const [actionFilter, setActionFilter] = useState('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  const load = useCallback(async () => {
    setLoading(true); setError('');
    try {
      const res = await adminDataApi.auditLogs({ page, limit: 50, action: actionFilter || undefined, search: search || undefined });
      setLogs(res.data.data);
      setTotal(res.data.total);
    } catch { setError('Failed to load audit logs'); }
    finally { setLoading(false); }
  }, [page, actionFilter, search]);

  useEffect(() => { load(); }, [load]);
  useEffect(() => { const t = setTimeout(() => setPage(1), 400); return () => clearTimeout(t); }, [search]);

  const byAction = (action: string) => logs.filter(l => l.action === action).length;

  return (
    <div className="p-4 md:p-6 space-y-6">
      <PageHeader
        title="Audit Logs"
        subtitle={loading ? 'Loading…' : `${total} events`}
        actions={
          <>
            <Btn variant="secondary" size="sm" onClick={load}><RefreshCw size={14} /></Btn>
            <Btn variant="secondary" size="sm"><Download size={14} />Export</Btn>
          </>
        }
      />

      <div className="flex flex-wrap gap-3">
        <SearchInput value={search} onChange={v => { setSearch(v); setPage(1); }} placeholder="Search by user, action, or IP…" className="flex-1 min-w-48" />
        <Select value={actionFilter} onChange={v => { setActionFilter(v); setPage(1); }} options={ACTION_OPTIONS} placeholder="All Actions" />
      </div>

      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        {[
          { label: 'Total Events', value: total, color: '#0ea5e9' },
          { label: 'Verifications', value: byAction('PAYMENT_VERIFIED') + byAction('PAYMENT_REJECTED'), color: '#B8FF3B' },
          { label: 'Logins', value: byAction('LOGIN') + byAction('ADMIN_LOGIN'), color: '#a78bfa' },
          { label: 'Fraud Events', value: byAction('FRAUD_DETECTED'), color: '#ef4444' },
        ].map(s => (
          <div key={s.label} className="bg-card rounded-2xl border border-slate-800 p-4">
            <p className="text-2xl font-bold" style={{ color: s.color }}>{s.value}</p>
            <p className="text-slate-500 text-xs mt-1">{s.label}</p>
          </div>
        ))}
      </div>

      {error && <p className="text-red-400 text-sm">{error}</p>}

      {loading ? <LoadingSkeleton rows={10} /> : (
        <div className="bg-card rounded-2xl border border-slate-800 overflow-hidden">
          <div className="overflow-x-auto scrollbar-thin">
            <table className="w-full text-sm">
              <thead className="bg-slate-900/80 sticky top-0 z-10">
                <tr>{['User', 'Action', 'IP Address', 'Metadata', 'Time'].map(h => (
                  <th key={h} className="px-4 py-3 text-left text-xs font-semibold text-slate-400 uppercase tracking-wider whitespace-nowrap">{h}</th>
                ))}</tr>
              </thead>
              <tbody className="divide-y divide-slate-800">
                {logs.map(log => (
                  <tr key={log.id} className="hover:bg-slate-800/30 transition-colors">
                    <td className="px-4 py-3">
                      <div className="flex items-center gap-2">
                        <EmployeeAvatar name={log.user?.fullName} id={log.userId ?? ''} size="sm" />
                        <div>
                          <p className="text-white text-sm font-medium">{log.user?.fullName ?? 'System'}</p>
                          <p className="text-slate-600 text-xs">{log.user?.phone ?? '—'}</p>
                        </div>
                      </div>
                    </td>
                    <td className="px-4 py-3">
                      <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg text-xs font-semibold"
                        style={{ background: `${ACTION_COLORS[log.action] ?? '#94a3b8'}18`, color: ACTION_COLORS[log.action] ?? '#94a3b8' }}>
                        <span className="w-1.5 h-1.5 rounded-full inline-block" style={{ background: ACTION_COLORS[log.action] ?? '#94a3b8' }} />
                        {log.action.replace(/_/g, ' ')}
                      </span>
                    </td>
                    <td className="px-4 py-3 text-slate-500 text-xs font-mono">{log.ipAddress ?? '—'}</td>
                    <td className="px-4 py-3 text-slate-500 text-xs max-w-xs truncate">{log.metadata ? JSON.stringify(log.metadata) : '—'}</td>
                    <td className="px-4 py-3">
                      <p className="text-slate-400 text-xs whitespace-nowrap">{formatDateTime(log.createdAt)}</p>
                      <p className="text-slate-600 text-xs">{formatRelative(log.createdAt)}</p>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          {logs.length === 0 && <p className="text-slate-500 text-sm text-center py-12">No logs found</p>}
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
