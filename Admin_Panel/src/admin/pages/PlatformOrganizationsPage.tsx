import { useState, useEffect, useCallback } from 'react';
import { RefreshCw, Search, Building2, Power } from 'lucide-react';
import { PageHeader, Btn } from '../components/layout/PageHeader';
import { ActiveBadge } from '../components/ui/Badges';
import { DataTable } from '../components/ui/DataTable';
import { formatDate } from '../utils';
import { platformAdminApi } from '../services/api';
import type { PlatformOrganization, TableColumn } from '../types';

export default function PlatformOrganizationsPage() {
  const [rows, setRows] = useState<PlatformOrganization[]>([]);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [search, setSearch] = useState('');
  const [status, setStatus] = useState('');
  const [page, setPage] = useState(1);
  const [busyId, setBusyId] = useState<string | null>(null);
  const limit = 20;

  const load = useCallback(async () => {
    setLoading(true);
    setError('');
    try {
      const res = await platformAdminApi.organizations({
        page, limit, search: search || undefined, status: status || undefined,
      });
      setRows(res.data.data);
      setTotal(res.data.total);
    } catch {
      setError('Failed to load organizations');
    } finally {
      setLoading(false);
    }
  }, [page, search, status]);

  useEffect(() => { load(); }, [load]);

  async function toggleStatus(org: PlatformOrganization) {
    setBusyId(org.id);
    try {
      const next = org.status === 'active' ? 'suspended' : 'active';
      await platformAdminApi.updateOrganization(org.id, { status: next });
      await load();
    } catch {
      setError('Failed to update organization');
    } finally {
      setBusyId(null);
    }
  }

  const columns: TableColumn<PlatformOrganization>[] = [
    {
      key: 'name', label: 'Organization', sortable: true,
      render: (_v, r) => (
        <div className="flex items-center gap-2">
          <div className="w-8 h-8 rounded-lg bg-slate-800 flex items-center justify-center flex-shrink-0">
            <Building2 size={14} className="text-slate-400" />
          </div>
          <div className="min-w-0">
            <p className="text-white text-sm font-medium truncate">{r.name}</p>
            <p className="text-slate-500 text-xs truncate">{r.email ?? r.phone ?? '—'}</p>
          </div>
        </div>
      ),
    },
    { key: 'type', label: 'Type' },
    {
      key: 'status', label: 'Status', sortable: true,
      render: (_v, r) => <ActiveBadge active={r.status === 'active'} />,
    },
    {
      key: 'userAssignments', label: 'Users',
      render: (_v, r) => <span className="text-slate-300">{r._count?.userAssignments ?? 0}</span>,
    },
    {
      key: 'branches', label: 'Branches',
      render: (_v, r) => <span className="text-slate-300">{r._count?.branches ?? 0}</span>,
    },
    {
      key: 'plan', label: 'Plan',
      render: (_v, r) => <span className="text-slate-300">{r.subscriptions?.[0]?.planName ?? r.subscriptionPlan ?? '—'}</span>,
    },
    { key: 'createdAt', label: 'Joined', sortable: true, render: v => formatDate(String(v)) },
    {
      key: 'actions', label: '',
      render: (_v, r) => (
        <Btn variant={r.status === 'active' ? 'danger' : 'primary'} size="sm"
          disabled={busyId === r.id}
          onClick={() => toggleStatus(r)}>
          <Power size={13} />{r.status === 'active' ? 'Suspend' : 'Activate'}
        </Btn>
      ),
    },
  ];

  const totalPages = Math.max(1, Math.ceil(total / limit));

  return (
    <div className="p-4 md:p-6 space-y-6">
      <PageHeader
        title="Organizations"
        subtitle={`${total} businesses on the platform`}
        actions={<Btn variant="secondary" size="sm" onClick={load}><RefreshCw size={14} /></Btn>}
      />

      <div className="flex flex-wrap items-center gap-3">
        <div className="relative flex-1 min-w-[200px]">
          <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-500" />
          <input
            value={search}
            onChange={e => { setPage(1); setSearch(e.target.value); }}
            placeholder="Search name, email, phone…"
            className="w-full bg-slate-900 border border-slate-700 rounded-xl pl-9 pr-4 py-2.5 text-sm text-white placeholder-slate-500 focus:outline-none focus:border-slate-500"
          />
        </div>
        <select
          value={status}
          onChange={e => { setPage(1); setStatus(e.target.value); }}
          className="bg-slate-900 border border-slate-700 rounded-xl px-3 py-2.5 text-sm text-white focus:outline-none focus:border-slate-500"
        >
          <option value="">All statuses</option>
          <option value="active">Active</option>
          <option value="suspended">Suspended</option>
          <option value="inactive">Inactive</option>
        </select>
      </div>

      {error && <p className="text-red-400 text-sm">{error}</p>}

      <DataTable
        columns={columns}
        data={rows}
        loading={loading}
        pageSize={limit}
        emptyMessage="No organizations found"
      />

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