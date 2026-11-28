import { useState, useEffect, useCallback } from 'react';
import { RefreshCw } from 'lucide-react';
import { PageHeader, Btn } from '../components/layout/PageHeader';
import { DataTable } from '../components/ui/DataTable';
import { formatDate } from '../utils';
import { platformAdminApi } from '../services/api';
import type { PlatformSubscription, TableColumn, SubscriptionStatus } from '../types';

const STATUS_STYLE: Record<SubscriptionStatus, { bg: string; color: string }> = {
  ACTIVE: { bg: 'rgba(184,255,59,0.12)', color: '#B8FF3B' },
  INACTIVE: { bg: 'rgba(100,116,139,0.2)', color: '#94a3b8' },
  CANCELLED: { bg: 'rgba(239,68,68,0.12)', color: '#ef4444' },
  EXPIRED: { bg: 'rgba(245,158,11,0.12)', color: '#f59e0b' },
};

export default function PlatformSubscriptionsPage() {
  const [rows, setRows] = useState<PlatformSubscription[]>([]);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [page, setPage] = useState(1);
  const limit = 20;

  const load = useCallback(async () => {
    setLoading(true);
    setError('');
    try {
      const res = await platformAdminApi.subscriptions({ page, limit });
      setRows(res.data.data);
      setTotal(res.data.total);
    } catch {
      setError('Failed to load subscriptions');
    } finally {
      setLoading(false);
    }
  }, [page]);

  useEffect(() => { load(); }, [load]);

  const columns: TableColumn<PlatformSubscription>[] = [
    { key: 'organization', label: 'Organization', render: (_v, r) => r.organization?.name ?? r.organizationId },
    { key: 'planName', label: 'Plan', sortable: true },
    {
      key: 'status', label: 'Status', sortable: true,
      render: (_v, r) => {
        const c = STATUS_STYLE[r.status] ?? STATUS_STYLE.INACTIVE;
        return (
          <span className="inline-flex items-center px-2.5 py-1 rounded-lg text-xs font-semibold"
            style={{ background: c.bg, color: c.color }}>
            {r.status}
          </span>
        );
      },
    },
    { key: 'maxUsers', label: 'Max Users', render: v => (v == null ? '—' : String(v)) },
    { key: 'maxDevices', label: 'Max Devices', render: v => (v == null ? '—' : String(v)) },
    { key: 'startDate', label: 'Start', sortable: true, render: v => formatDate(String(v)) },
    { key: 'endDate', label: 'End', render: v => (v ? formatDate(String(v)) : '—') },
  ];

  const totalPages = Math.max(1, Math.ceil(total / limit));

  return (
    <div className="p-4 md:p-6 space-y-6">
      <PageHeader
        title="Subscriptions"
        subtitle={`${total} subscription records`}
        actions={<Btn variant="secondary" size="sm" onClick={load}><RefreshCw size={14} /></Btn>}
      />
      {error && <p className="text-red-400 text-sm">{error}</p>}
      <DataTable columns={columns} data={rows} loading={loading} pageSize={limit} emptyMessage="No subscriptions found" />
      {totalPages > 1 && (
        <div className="flex items-center justify-center gap-2">
          <Btn variant="secondary" size="sm" disabled={page === 1} onClick={() => setPage(p => p - 1)}>Prev</Btn>
          <span className="text-slate-500 text-xs">Page {page} of {totalPages}</span>
          <Btn variant="secondary" size="sm" disabled={page === totalPages} onClick={() => setPage(p => p + 1)}>Next</Btn>
        </div>
      )}
    </div>
  );
}