import { useState, useEffect, useCallback } from 'react';
import { RefreshCw, Search } from 'lucide-react';
import { PageHeader, Btn } from '../components/layout/PageHeader';
import { StatusBadge } from '../components/ui/Badges';
import { DataTable } from '../components/ui/DataTable';
import { formatCurrency, formatDateTime } from '../utils';
import { platformAdminApi } from '../services/api';
import type { PlatformPayment, TableColumn } from '../types';

export default function PlatformTransactionsPage() {
  const [rows, setRows] = useState<PlatformPayment[]>([]);
  const [total, setTotal] = useState(0);
  const [totalAmount, setTotalAmount] = useState(0);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [search, setSearch] = useState('');
  const [status, setStatus] = useState('');
  const [page, setPage] = useState(1);
  const limit = 20;

  const load = useCallback(async () => {
    setLoading(true);
    setError('');
    try {
      const res = await platformAdminApi.payments({
        page, limit, search: search || undefined, status: status || undefined,
      });
      setRows(res.data.data);
      setTotal(res.data.total);
      setTotalAmount(res.data.totalAmount);
    } catch {
      setError('Failed to load transactions');
    } finally {
      setLoading(false);
    }
  }, [page, search, status]);

  useEffect(() => { load(); }, [load]);

  const columns: TableColumn<PlatformPayment>[] = [
    { key: 'transactionId', label: 'Reference', sortable: true },
    { key: 'organization', label: 'Organization', render: (_v, r) => r.organization?.name ?? r.organizationId },
    { key: 'senderName', label: 'Sender', render: v => (v == null ? '—' : String(v)) },
    { key: 'amount', label: 'Amount', sortable: true, render: (_v, r) => formatCurrency(Number(r.amount), r.currency) },
    { key: 'status', label: 'Status', sortable: true, render: (_v, r) => <StatusBadge status={r.status} /> },
    { key: 'createdAt', label: 'Date', sortable: true, render: v => formatDateTime(String(v)) },
  ];

  const totalPages = Math.max(1, Math.ceil(total / limit));

  return (
    <div className="p-4 md:p-6 space-y-6">
      <PageHeader
        title="All Transactions"
        subtitle={`${total} verifications · ${formatCurrency(totalAmount)} total`}
        actions={<Btn variant="secondary" size="sm" onClick={load}><RefreshCw size={14} /></Btn>}
      />

      <div className="flex flex-wrap items-center gap-3">
        <div className="relative flex-1 min-w-[200px]">
          <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-500" />
          <input
            value={search}
            onChange={e => { setPage(1); setSearch(e.target.value); }}
            placeholder="Search reference or sender…"
            className="w-full bg-slate-900 border border-slate-700 rounded-xl pl-9 pr-4 py-2.5 text-sm text-white placeholder-slate-500 focus:outline-none focus:border-slate-500"
          />
        </div>
        <select
          value={status}
          onChange={e => { setPage(1); setStatus(e.target.value); }}
          className="bg-slate-900 border border-slate-700 rounded-xl px-3 py-2.5 text-sm text-white focus:outline-none focus:border-slate-500"
        >
          <option value="">All statuses</option>
          <option value="VERIFIED">Verified</option>
          <option value="PENDING">Pending</option>
          <option value="REJECTED">Rejected</option>
          <option value="FAILED">Failed</option>
        </select>
      </div>

      {error && <p className="text-red-400 text-sm">{error}</p>}

      <DataTable columns={columns} data={rows} loading={loading} pageSize={limit} emptyMessage="No transactions found" />

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