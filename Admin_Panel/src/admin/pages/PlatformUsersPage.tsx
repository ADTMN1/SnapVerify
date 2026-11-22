import { useState, useEffect, useCallback } from 'react';
import { RefreshCw, Search, ShieldCheck, ShieldOff, Power } from 'lucide-react';
import { PageHeader, Btn } from '../components/layout/PageHeader';
import { ActiveBadge } from '../components/ui/Badges';
import { DataTable } from '../components/ui/DataTable';
import { formatDate } from '../utils';
import { platformAdminApi } from '../services/api';
import type { PlatformUser, TableColumn } from '../types';

export default function PlatformUsersPage() {
  const [rows, setRows] = useState<PlatformUser[]>([]);
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
      const res = await platformAdminApi.users({
        page, limit, search: search || undefined, status: status || undefined,
      });
      setRows(res.data.data);
      setTotal(res.data.total);
    } catch {
      setError('Failed to load users');
    } finally {
      setLoading(false);
    }
  }, [page, search, status]);

  useEffect(() => { load(); }, [load]);

  async function updateUser(user: PlatformUser, data: { status?: string; isPlatformAdmin?: boolean }) {
    setBusyId(user.id);
    try {
      await platformAdminApi.updateUser(user.id, data);
      await load();
    } catch {
      setError('Failed to update user');
    } finally {
      setBusyId(null);
    }
  }

  const columns: TableColumn<PlatformUser>[] = [
    {
      key: 'fullName', label: 'User', sortable: true,
      render: (_v, r) => (
        <div className="min-w-0">
          <p className="text-white text-sm font-medium truncate">{r.fullName ?? '—'}</p>
          <p className="text-slate-500 text-xs truncate">{r.email ?? r.phone ?? '—'}</p>
        </div>
      ),
    },
    {
      key: 'userAssignments', label: 'Organizations',
      render: (_v, r) => (
        <span className="text-slate-300">
          {r.userAssignments?.length
            ? r.userAssignments.map(a => a.organization?.name ?? a.organizationId).join(', ')
            : '—'}
        </span>
      ),
    },
    {
      key: 'isPlatformAdmin', label: 'Access', sortable: true,
      render: (_v, r) => r.isPlatformAdmin
        ? <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-lg text-xs font-semibold"
            style={{ background: 'rgba(184,255,59,0.12)', color: '#B8FF3B' }}>
            <ShieldCheck size={12} />Super Admin
          </span>
        : <span className="text-slate-500 text-xs">Standard</span>,
    },
    {
      key: 'status', label: 'Status', sortable: true,
      render: (_v, r) => <ActiveBadge active={r.status === 'active'} />,
    },
    { key: 'createdAt', label: 'Joined', sortable: true, render: v => formatDate(String(v)) },
    {
      key: 'actions', label: '',
      render: (_v, r) => (
        <div className="flex items-center gap-1">
          <Btn variant={r.isPlatformAdmin ? 'secondary' : 'primary'} size="sm"
            disabled={busyId === r.id}
            onClick={() => updateUser(r, { isPlatformAdmin: !r.isPlatformAdmin })}>
            {r.isPlatformAdmin ? <ShieldOff size={13} /> : <ShieldCheck size={13} />}
            {r.isPlatformAdmin ? 'Revoke' : 'Make admin'}
          </Btn>
          <Btn variant="secondary" size="sm" disabled={busyId === r.id}
            onClick={() => updateUser(r, { status: r.status === 'active' ? 'suspended' : 'active' })}>
            <Power size={13} />
          </Btn>
        </div>
      ),
    },
  ];

  const totalPages = Math.max(1, Math.ceil(total / limit));

  return (
    <div className="p-4 md:p-6 space-y-6">
      <PageHeader
        title="Users"
        subtitle={`${total} users across all organizations`}
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
        emptyMessage="No users found"
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