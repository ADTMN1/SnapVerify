import { useEffect, useState, useCallback } from 'react';
import { Download, RefreshCw } from 'lucide-react';
import { AreaChart, Area, BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer, Legend } from 'recharts';
import { PageHeader, Btn } from '../components/layout/PageHeader';
import { ChartCard } from '../components/ui/Cards';
import { formatCurrency } from '../utils';
import { adminDashboardApi, type DashboardStats } from '../services/api';

const TT = { backgroundColor: '#0D1926', border: '1px solid #334155', borderRadius: 12, color: '#f1f5f9', fontSize: 12 };

export default function ReportsPage() {
  const [stats, setStats] = useState<DashboardStats | null>(null);
  const [revenue, setRevenue] = useState<{ date: string; value: number }[]>([]);
  const [verify, setVerify] = useState<any[]>([]);
  const [branches, setBranches] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const [s, rv, vt, bp] = await Promise.all([
        adminDashboardApi.stats(),
        adminDashboardApi.revenueTrend(7),
        adminDashboardApi.verificationTrend(7),
        adminDashboardApi.branchPerformance(),
      ]);
      setStats(s.data);
      setRevenue(rv.data);
      setVerify(vt.data);
      setBranches(bp.data);
    } catch { /* ignore */ }
    finally { setLoading(false); }
  }, []);

  useEffect(() => { load(); }, [load]);

  return (
    <div className="p-4 md:p-6 space-y-6">
      <PageHeader title="Reports" subtitle="Business performance overview"
        actions={
          <>
            <Btn variant="secondary" size="sm" onClick={load}><RefreshCw size={14} /></Btn>
            <Btn><Download size={14} />Export All</Btn>
          </>
        }
      />

      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        {[
          { label: 'Total Verified', value: stats?.totalVerified ?? '—', color: '#B8FF3B' },
          { label: 'Today Transactions', value: stats?.todayTransactions ?? '—', color: '#0ea5e9' },
          { label: 'Fraud Alerts', value: stats?.fraudAlerts ?? '—', color: '#ef4444' },
          { label: "Today's Revenue", value: stats ? formatCurrency(stats.todayRevenue) : '—', color: '#a78bfa' },
        ].map(s => (
          <div key={s.label} className="bg-card rounded-2xl border border-slate-800 p-4">
            <p className="text-2xl font-bold" style={{ color: s.color }}>{loading ? '—' : s.value}</p>
            <p className="text-slate-500 text-xs mt-1">{s.label}</p>
          </div>
        ))}
      </div>

      <ChartCard title="Revenue (Last 7 Days)" subtitle="ETB" action={<Btn variant="secondary" size="sm"><Download size={12} />CSV</Btn>}>
        <ResponsiveContainer width="100%" height={220}>
          <AreaChart data={revenue}>
            <defs>
              <linearGradient id="rg" x1="0" y1="0" x2="0" y2="1">
                <stop offset="5%" stopColor="#B8FF3B" stopOpacity={0.3} />
                <stop offset="95%" stopColor="#B8FF3B" stopOpacity={0} />
              </linearGradient>
            </defs>
            <XAxis dataKey="date" tick={{ fill: '#64748b', fontSize: 11 }} tickFormatter={d => d.slice(5)} axisLine={false} tickLine={false} />
            <YAxis tick={{ fill: '#64748b', fontSize: 11 }} axisLine={false} tickLine={false} tickFormatter={v => `${(v / 1000).toFixed(0)}k`} />
            <Tooltip contentStyle={TT} formatter={(v) => [formatCurrency(Number(v ?? 0)), 'Revenue']} />
            <Area type="monotone" dataKey="value" stroke="#B8FF3B" strokeWidth={2} fill="url(#rg)" />
          </AreaChart>
        </ResponsiveContainer>
      </ChartCard>

      <ChartCard title="Verification Trend" subtitle="7 days" action={<Btn variant="secondary" size="sm"><Download size={12} />CSV</Btn>}>
        <ResponsiveContainer width="100%" height={220}>
          <BarChart data={verify} barSize={8}>
            <XAxis dataKey="date" tick={{ fill: '#64748b', fontSize: 11 }} tickFormatter={d => d.slice(5)} axisLine={false} tickLine={false} />
            <YAxis tick={{ fill: '#64748b', fontSize: 11 }} axisLine={false} tickLine={false} />
            <Tooltip contentStyle={TT} />
            <Legend wrapperStyle={{ fontSize: 11, color: '#94a3b8' }} />
            <Bar dataKey="verified" fill="#B8FF3B" radius={[4, 4, 0, 0]} name="Verified" />
            <Bar dataKey="rejected" fill="#ef4444" radius={[4, 4, 0, 0]} name="Rejected" />
            <Bar dataKey="failed" fill="#f59e0b" radius={[4, 4, 0, 0]} name="Failed" />
          </BarChart>
        </ResponsiveContainer>
      </ChartCard>

      <div className="bg-card rounded-2xl border border-slate-800 overflow-hidden">
        <div className="px-5 py-4 border-b border-slate-800 flex items-center justify-between">
          <h3 className="text-white font-semibold text-sm">Branch Performance</h3>
          <Btn variant="secondary" size="sm"><Download size={12} />CSV</Btn>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead className="bg-slate-900/80">
              <tr>{['Branch', 'Verification Rate', 'Revenue', 'Staff'].map(h => (
                <th key={h} className="px-4 py-3 text-left text-xs font-semibold text-slate-400 uppercase tracking-wider">{h}</th>
              ))}</tr>
            </thead>
            <tbody className="divide-y divide-slate-800">
              {branches.map(b => (
                <tr key={b.branchId} className="hover:bg-slate-800/30">
                  <td className="px-4 py-3 text-white font-medium">{b.branchName}</td>
                  <td className="px-4 py-3 text-[#B8FF3B] font-semibold">{b.verificationRate.toFixed(1)}%</td>
                  <td className="px-4 py-3 text-white">{formatCurrency(b.revenue)}</td>
                  <td className="px-4 py-3 text-slate-300">{b.employees}</td>
                </tr>
              ))}
              {branches.length === 0 && !loading && (
                <tr><td colSpan={4} className="px-4 py-8 text-center text-slate-500 text-sm">No branch data yet.</td></tr>
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
