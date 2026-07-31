import { useState, useEffect, useCallback } from 'react';
import { ShieldAlert, AlertTriangle, Eye, RefreshCw } from 'lucide-react';
import { PageHeader } from '../components/layout/PageHeader';
import { RiskBadge, StatusBadge } from '../components/ui/Badges';
import { Drawer } from '../components/ui/Overlays';
import { VerificationTimeline } from '../components/ui/Timeline';
import { LoadingSkeleton } from '../components/ui/LoadingSkeleton';
import { formatCurrency, formatDateTime } from '../utils';
import { adminDataApi } from '../services/api';
import type { Payment, VerificationLog } from '../types';

export default function FraudCenterPage() {
  const [payments, setPayments] = useState<Payment[]>([]);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [selected, setSelected] = useState<Payment | null>(null);

  const load = useCallback(async () => {
    setLoading(true); setError('');
    try {
      const res = await adminDataApi.fraud({ limit: 50, minRisk: 60 });
      setPayments(res.data.data);
      setTotal(res.data.total);
    } catch { setError('Failed to load fraud data'); }
    finally { setLoading(false); }
  }, []);

  useEffect(() => { load(); }, [load]);

  const critical = payments.filter(p => (p.riskScore ?? 0) >= 80).length;
  const high = payments.filter(p => (p.riskScore ?? 0) >= 60 && (p.riskScore ?? 0) < 80).length;

  return (
    <div className="p-4 md:p-6 space-y-6">
      <PageHeader title="Fraud Center" subtitle="High-risk transactions and suspicious activity"
        actions={<button onClick={load} className="p-2 rounded-xl text-slate-400 hover:text-white hover:bg-slate-800 transition-colors"><RefreshCw size={16} /></button>} />

      {total > 0 && (
        <div className="rounded-2xl p-4 border border-red-500/30 flex items-center gap-3" style={{ background: 'rgba(239,68,68,0.08)' }}>
          <ShieldAlert size={20} className="text-red-400 flex-shrink-0" />
          <div>
            <p className="text-red-400 font-semibold text-sm">{total} High-Risk Transaction{total !== 1 ? 's' : ''} Detected</p>
            <p className="text-slate-400 text-xs">Immediate review recommended</p>
          </div>
        </div>
      )}

      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        {[
          { label: 'Total Flagged', value: total, color: '#ef4444' },
          { label: 'Critical (80+)', value: critical, color: '#dc2626' },
          { label: 'High (60–79)', value: high, color: '#f59e0b' },
          { label: 'Fraud Rate', value: total > 0 ? `${((critical / Math.max(total, 1)) * 100).toFixed(1)}%` : '0%', color: '#0ea5e9' },
        ].map(s => (
          <div key={s.label} className="bg-card rounded-2xl p-4 border border-slate-800">
            <p className="text-2xl font-bold" style={{ color: s.color }}>{s.value}</p>
            <p className="text-slate-500 text-xs mt-1">{s.label}</p>
          </div>
        ))}
      </div>

      {error && <p className="text-red-400 text-sm">{error}</p>}

      {loading ? <LoadingSkeleton rows={8} /> : (
        <div className="bg-card rounded-2xl border border-slate-800 overflow-hidden">
          <div className="px-5 py-4 border-b border-slate-800 flex items-center gap-2">
            <AlertTriangle size={16} className="text-red-400" />
            <h3 className="text-white font-semibold text-sm">High Risk Transactions</h3>
          </div>
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="bg-slate-900/80">
                <tr>{['Transaction ID', 'Sender', 'Amount', 'Risk', 'Status', 'Time', ''].map(h => (
                  <th key={h} className="px-4 py-3 text-left text-xs font-semibold text-slate-400 uppercase tracking-wider whitespace-nowrap">{h}</th>
                ))}</tr>
              </thead>
              <tbody className="divide-y divide-slate-800">
                {payments.map(p => (
                  <tr key={p.id} className="hover:bg-slate-800/30 transition-colors">
                    <td className="px-4 py-3 font-mono text-slate-300 text-xs">{p.transactionId}</td>
                    <td className="px-4 py-3 text-white font-medium">{p.senderName ?? '—'}</td>
                    <td className="px-4 py-3 text-[#B8FF3B] font-semibold">{formatCurrency(p.amount)}</td>
                    <td className="px-4 py-3"><RiskBadge score={p.riskScore ?? 0} /></td>
                    <td className="px-4 py-3"><StatusBadge status={p.status} /></td>
                    <td className="px-4 py-3 text-slate-500 text-xs">{formatDateTime(p.createdAt)}</td>
                    <td className="px-4 py-3">
                      <button onClick={() => setSelected(p)} className="p-1.5 rounded-lg text-slate-400 hover:text-white hover:bg-slate-800 transition-colors"><Eye size={14} /></button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          {payments.length === 0 && <p className="text-slate-500 text-sm text-center py-12">No high-risk transactions found.</p>}
        </div>
      )}

      <Drawer open={!!selected} onClose={() => setSelected(null)} title="Fraud Investigation">
        {selected && (
          <div className="p-6 space-y-5">
            <div className="rounded-xl p-4 border border-red-500/30" style={{ background: 'rgba(239,68,68,0.08)' }}>
              <p className="text-red-400 font-semibold text-sm mb-2">Risk Assessment</p>
              <RiskBadge score={selected.riskScore ?? 0} />
            </div>
            <div className="space-y-2">
              {[
                { label: 'Transaction ID', value: selected.transactionId },
                { label: 'Amount', value: formatCurrency(selected.amount) },
                { label: 'Sender', value: selected.senderName ?? '—' },
                { label: 'Method', value: selected.paymentMethod },
                { label: 'Date', value: formatDateTime(selected.createdAt) },
              ].map(i => (
                <div key={i.label} className="flex justify-between py-2 border-b border-slate-800">
                  <span className="text-slate-500 text-sm">{i.label}</span>
                  <span className="text-white text-sm font-medium">{i.value}</span>
                </div>
              ))}
            </div>
            {selected.verificationLogs && selected.verificationLogs.length > 0 && (
              <div>
                <p className="text-white font-semibold text-sm mb-3">Verification History</p>
                <VerificationTimeline logs={selected.verificationLogs as VerificationLog[]} />
              </div>
            )}
          </div>
        )}
      </Drawer>
    </div>
  );
}
