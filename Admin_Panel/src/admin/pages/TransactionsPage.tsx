import { useState, useEffect, useCallback } from 'react';
import { Download, Eye, RefreshCw } from 'lucide-react';
import { PageHeader, Btn } from '../components/layout/PageHeader';
import { DataTable } from '../components/ui/DataTable';
import { StatusBadge, RiskBadge } from '../components/ui/Badges';
import { SearchInput, Select } from '../components/ui/Overlays';
import { Drawer } from '../components/ui/Overlays';
import { VerificationTimeline, EmployeeAvatar } from '../components/ui/Timeline';
import { formatCurrency, formatDateTime, formatRelative } from '../utils';
import { adminDataApi } from '../services/api';
import type { Payment, VerificationLog } from '../types';
import type { TableColumn } from '../types';

const STATUS_OPTIONS = [
  { label: 'Verified', value: 'VERIFIED' },
  { label: 'Pending', value: 'PENDING' },
  { label: 'Rejected', value: 'REJECTED' },
  { label: 'Failed', value: 'FAILED' },
];

export default function TransactionsPage() {
  const [payments, setPayments] = useState<Payment[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [selected, setSelected] = useState<Payment | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    setError('');
    try {
      const res = await adminDataApi.payments({ page, limit: 20, status: statusFilter || undefined, search: search || undefined });
      setPayments(res.data.data);
      setTotal(res.data.total);
    } catch {
      setError('Failed to load transactions');
    } finally {
      setLoading(false);
    }
  }, [page, statusFilter, search]);

  useEffect(() => { load(); }, [load]);

  // debounce search
  useEffect(() => {
    const t = setTimeout(() => { setPage(1); }, 400);
    return () => clearTimeout(t);
  }, [search]);

  const columns: TableColumn<Payment>[] = [
    { key: 'transactionId', label: 'Transaction ID', sortable: true },
    { key: 'senderName', label: 'Sender', render: (_, r) => <span className="text-white font-medium">{r.senderName ?? '—'}</span> },
    { key: 'amount', label: 'Amount', sortable: true, render: (_, r) => <span className="text-[#B8FF3B] font-semibold">{formatCurrency(r.amount)}</span> },
    { key: 'paymentMethod', label: 'Method', render: (_, r) => <span className="text-slate-400 text-xs">{r.paymentMethod}</span> },
    { key: 'status', label: 'Status', render: (_, r) => <StatusBadge status={r.status} /> },
    { key: 'riskScore', label: 'Risk', render: (_, r) => r.riskScore != null ? <RiskBadge score={r.riskScore} /> : <span className="text-slate-600">—</span> },
    { key: 'createdAt', label: 'Time', sortable: true, render: (_, r) => <span className="text-slate-500 text-xs">{formatRelative(r.createdAt)}</span> },
    { key: 'id', label: '', render: (_, r) => (
      <button onClick={e => { e.stopPropagation(); setSelected(r); }} className="p-1.5 rounded-lg text-slate-500 hover:text-white hover:bg-slate-800 transition-colors">
        <Eye size={14} />
      </button>
    )},
  ];

  return (
    <div className="p-4 md:p-6">
      <PageHeader
        title="Transactions"
        subtitle={loading ? 'Loading…' : `${total} records`}
        actions={
          <>
            <Btn variant="secondary" size="sm" onClick={load}><RefreshCw size={14} />Refresh</Btn>
            <Btn variant="primary" size="sm"><Download size={14} />Export</Btn>
          </>
        }
      />

      <div className="flex flex-wrap gap-3 mb-5">
        <SearchInput value={search} onChange={v => { setSearch(v); setPage(1); }} placeholder="Search by ID or sender…" className="flex-1 min-w-48" />
        <Select value={statusFilter} onChange={v => { setStatusFilter(v); setPage(1); }} options={STATUS_OPTIONS} placeholder="All Statuses" />
      </div>

      {error && <p className="text-red-400 text-sm mb-4">{error}</p>}

      <DataTable columns={columns} data={payments} loading={loading} onRowClick={r => setSelected(r)} pageSize={20} emptyMessage="No transactions found" />

      {/* pagination for server-side */}
      {!loading && total > 20 && (
        <div className="flex justify-center gap-2 mt-4">
          <Btn variant="secondary" size="sm" onClick={() => setPage(p => Math.max(1, p - 1))} disabled={page === 1}>Prev</Btn>
          <span className="text-slate-400 text-sm self-center">Page {page} of {Math.ceil(total / 20)}</span>
          <Btn variant="secondary" size="sm" onClick={() => setPage(p => p + 1)} disabled={page >= Math.ceil(total / 20)}>Next</Btn>
        </div>
      )}

      <Drawer open={!!selected} onClose={() => setSelected(null)} title="Transaction Detail">
        {selected && (
          <div className="p-6 space-y-6">
            <div className="flex items-start justify-between">
              <div>
                <p className="text-slate-400 text-xs mb-1">Transaction ID</p>
                <p className="text-white font-mono font-semibold">{selected.transactionId}</p>
              </div>
              <StatusBadge status={selected.status} />
            </div>
            <div className="bg-slate-900 rounded-2xl p-4 text-center">
              <p className="text-slate-400 text-xs mb-1">Amount</p>
              <p className="text-[#B8FF3B] text-3xl font-black">{formatCurrency(selected.amount)}</p>
            </div>
            <div className="space-y-3">
              {[
                { label: 'Sender', value: selected.senderName ?? '—' },
                { label: 'Receiver', value: selected.receiverName ?? '—' },
                { label: 'Method', value: selected.paymentMethod },
                { label: 'Date', value: formatDateTime(selected.createdAt) },
              ].map(item => (
                <div key={item.label} className="flex justify-between items-center py-2 border-b border-slate-800">
                  <span className="text-slate-500 text-sm">{item.label}</span>
                  <span className="text-white text-sm font-medium">{item.value}</span>
                </div>
              ))}
              {selected.riskScore != null && (
                <div className="flex justify-between items-center py-2 border-b border-slate-800">
                  <span className="text-slate-500 text-sm">Risk Score</span>
                  <RiskBadge score={selected.riskScore} />
                </div>
              )}
            </div>
            {selected.verificationLogs && selected.verificationLogs.length > 0 && (
              <div>
                <p className="text-white font-semibold text-sm mb-3">Verification Timeline</p>
                <VerificationTimeline logs={selected.verificationLogs as VerificationLog[]} />
              </div>
            )}
            {selected.user && (
              <div>
                <p className="text-white font-semibold text-sm mb-3">Verified By</p>
                <div className="flex items-center gap-3 bg-slate-900 rounded-xl p-3">
                  <EmployeeAvatar name={selected.user.fullName} id={selected.userId ?? ''} />
                  <div>
                    <p className="text-white text-sm font-medium">{selected.user.fullName ?? '—'}</p>
                    <p className="text-slate-500 text-xs">{selected.user.phone}</p>
                  </div>
                </div>
              </div>
            )}
            {selected.rawData && (
              <div>
                <p className="text-white font-semibold text-sm mb-2">Raw Data</p>
                <pre className="bg-slate-900 rounded-xl p-3 text-xs text-slate-400 overflow-x-auto scrollbar-thin">
                  {JSON.stringify(selected.rawData, null, 2)}
                </pre>
              </div>
            )}
          </div>
        )}
      </Drawer>
    </div>
  );
}
