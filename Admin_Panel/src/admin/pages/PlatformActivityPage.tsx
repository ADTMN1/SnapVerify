import { useState, useEffect, useCallback } from 'react';
import { RefreshCw } from 'lucide-react';
import { PageHeader, Btn } from '../components/layout/PageHeader';
import { EmployeeAvatar } from '../components/ui/Timeline';
import { formatRelative } from '../utils';
import { platformAdminApi } from '../services/api';
import type { PlatformActivity } from '../types';

export default function PlatformActivityPage() {
  const [rows, setRows] = useState<PlatformActivity[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  const load = useCallback(async () => {
    setLoading(true);
    setError('');
    try {
      const res = await platformAdminApi.activity(100);
      setRows(res.data);
    } catch {
      setError('Failed to load activity');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { load(); }, [load]);

  return (
    <div className="p-4 md:p-6 space-y-6">
      <PageHeader
        title="Platform Activity"
        subtitle="Audit trail across all organizations"
        actions={<Btn variant="secondary" size="sm" onClick={load}><RefreshCw size={14} /></Btn>}
      />
      {error && <p className="text-red-400 text-sm">{error}</p>}

      <div className="bg-card rounded-2xl border border-slate-800 p-5">
        {loading ? (
          <p className="text-slate-500 text-sm text-center py-8">Loading…</p>
        ) : rows.length === 0 ? (
          <p className="text-slate-500 text-sm text-center py-8">No activity yet</p>
        ) : (
          <div className="space-y-3">
            {rows.map(log => (
              <div key={log.id} className="flex items-center gap-3">
                <EmployeeAvatar name={log.user?.fullName} id={log.userId ?? ''} size="sm" />
                <div className="flex-1 min-w-0">
                  <p className="text-white text-xs font-medium truncate">
                    {log.user?.fullName ?? 'System'}
                    {log.organization?.name && (
                      <span className="text-slate-500"> · {log.organization.name}</span>
                    )}
                  </p>
                  <p className="text-slate-500 text-xs">{log.action.replace(/_/g, ' ')}</p>
                </div>
                <time className="text-slate-600 text-xs flex-shrink-0">{formatRelative(log.createdAt)}</time>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}