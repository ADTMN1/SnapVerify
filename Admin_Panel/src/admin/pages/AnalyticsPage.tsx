import { useEffect, useState, useCallback } from 'react';
import { AreaChart, Area, BarChart, Bar, LineChart, Line, XAxis, YAxis, Tooltip, ResponsiveContainer, CartesianGrid, Legend } from 'recharts';
import { PageHeader } from '../components/layout/PageHeader';
import { ChartCard } from '../components/ui/Cards';
import { formatCurrency } from '../utils';
import { adminDashboardApi } from '../services/api';
import { PROVIDER_COLORS, PROVIDER_LABELS } from '../constants';

const TT = { backgroundColor: '#0D1926', border: '1px solid #334155', borderRadius: 12, color: '#f1f5f9', fontSize: 12 };

export default function AnalyticsPage() {
  const [revenue, setRevenue] = useState<{ date: string; value: number }[]>([]);
  const [verify, setVerify] = useState<any[]>([]);
  const [providers, setProviders] = useState<any[]>([]);
  const [branches, setBranches] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const [rv, vt, ps, bp] = await Promise.all([
        adminDashboardApi.revenueTrend(14),
        adminDashboardApi.verificationTrend(14),
        adminDashboardApi.providerStats(),
        adminDashboardApi.branchPerformance(),
      ]);
      setRevenue(rv.data);
      setVerify(vt.data);
      setProviders(ps.data);
      setBranches(bp.data);
    } catch { /* ignore */ }
    finally { setLoading(false); }
  }, []);

  useEffect(() => { load(); }, [load]);

  const totalVerified = verify.reduce((a, d) => a + (d.verified ?? 0), 0);
  const totalRejected = verify.reduce((a, d) => a + (d.rejected ?? 0), 0);
  const totalRevenue = revenue.reduce((a, d) => a + d.value, 0);
  const verifyRate = totalVerified + totalRejected > 0 ? ((totalVerified / (totalVerified + totalRejected)) * 100).toFixed(1) : '—';

  return (
    <div className="p-4 md:p-6 space-y-6">
      <PageHeader title="Analytics" subtitle="14-day business performance" />

      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        {[
          { label: 'Verification Rate', value: loading ? '—' : `${verifyRate}%`, color: '#B8FF3B' },
          { label: 'Total Verified', value: loading ? '—' : totalVerified, color: '#0ea5e9' },
          { label: 'Total Revenue', value: loading ? '—' : formatCurrency(totalRevenue), color: '#a78bfa' },
          { label: 'Providers Active', value: loading ? '—' : providers.length, color: '#f59e0b' },
        ].map(k => (
          <div key={k.label} className="bg-card rounded-2xl border border-slate-800 p-4">
            <p className="text-slate-500 text-xs mb-2">{k.label}</p>
            <p className="text-white text-xl font-bold">{k.value}</p>
          </div>
        ))}
      </div>

      <ChartCard title="Revenue Trend" subtitle="14 days">
        <ResponsiveContainer width="100%" height={240}>
          <AreaChart data={revenue}>
            <defs>
              <linearGradient id="ag" x1="0" y1="0" x2="0" y2="1">
                <stop offset="5%" stopColor="#B8FF3B" stopOpacity={0.3} />
                <stop offset="95%" stopColor="#B8FF3B" stopOpacity={0} />
              </linearGradient>
            </defs>
            <CartesianGrid strokeDasharray="3 3" stroke="#1e293b" />
            <XAxis dataKey="date" tick={{ fill: '#64748b', fontSize: 11 }} tickFormatter={d => d.slice(5)} axisLine={false} tickLine={false} />
            <YAxis tick={{ fill: '#64748b', fontSize: 11 }} axisLine={false} tickLine={false} tickFormatter={v => `${(v / 1000).toFixed(0)}k`} />
            <Tooltip contentStyle={TT} formatter={(v) => [formatCurrency(Number(v ?? 0)), 'Revenue']} />
            <Area type="monotone" dataKey="value" stroke="#B8FF3B" strokeWidth={2.5} fill="url(#ag)" dot={{ fill: '#B8FF3B', r: 2 }} />
          </AreaChart>
        </ResponsiveContainer>
      </ChartCard>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <ChartCard title="Verification Trend" subtitle="Daily breakdown">
          <ResponsiveContainer width="100%" height={220}>
            <LineChart data={verify}>
              <CartesianGrid strokeDasharray="3 3" stroke="#1e293b" />
              <XAxis dataKey="date" tick={{ fill: '#64748b', fontSize: 11 }} tickFormatter={d => d.slice(5)} axisLine={false} tickLine={false} />
              <YAxis tick={{ fill: '#64748b', fontSize: 11 }} axisLine={false} tickLine={false} />
              <Tooltip contentStyle={TT} />
              <Legend wrapperStyle={{ fontSize: 11, color: '#94a3b8' }} />
              <Line type="monotone" dataKey="verified" stroke="#B8FF3B" strokeWidth={2} dot={false} name="Verified" />
              <Line type="monotone" dataKey="rejected" stroke="#ef4444" strokeWidth={2} dot={false} name="Rejected" />
              <Line type="monotone" dataKey="failed" stroke="#f59e0b" strokeWidth={2} dot={false} name="Failed" />
            </LineChart>
          </ResponsiveContainer>
        </ChartCard>

        <ChartCard title="Provider Volume" subtitle="By verification count">
          <ResponsiveContainer width="100%" height={220}>
            <BarChart data={providers} barSize={18}>
              <XAxis dataKey="provider" tick={{ fill: '#64748b', fontSize: 11 }} tickFormatter={p => PROVIDER_LABELS[p as keyof typeof PROVIDER_LABELS] ?? p} axisLine={false} tickLine={false} />
              <YAxis tick={{ fill: '#64748b', fontSize: 11 }} axisLine={false} tickLine={false} />
              <Tooltip contentStyle={TT} labelFormatter={p => PROVIDER_LABELS[p as keyof typeof PROVIDER_LABELS] ?? p} />
              <Bar dataKey="count" radius={[4, 4, 0, 0]} name="Verifications"
                fill="#B8FF3B" />
            </BarChart>
          </ResponsiveContainer>
        </ChartCard>
      </div>

      <ChartCard title="Branch Performance" subtitle="Verification rate %">
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-3 mt-2">
          {branches.map(b => (
            <div key={b.branchId} className="rounded-xl p-4 border border-slate-800 bg-slate-900">
              <p className="text-white font-semibold text-sm">{b.branchName}</p>
              <p className="text-[#B8FF3B] text-2xl font-black mt-1">{b.verificationRate.toFixed(1)}%</p>
              <p className="text-slate-500 text-xs">verification rate</p>
              <p className="text-slate-400 text-xs mt-1">{formatCurrency(b.revenue)} revenue</p>
              <div className="mt-2 h-1.5 rounded-full bg-slate-800 overflow-hidden">
                <div className="h-full rounded-full bg-[#B8FF3B]" style={{ width: `${Math.min(b.verificationRate, 100)}%` }} />
              </div>
            </div>
          ))}
          {branches.length === 0 && !loading && <p className="text-slate-500 text-sm col-span-3 py-6 text-center">No branch data yet.</p>}
        </div>
      </ChartCard>
    </div>
  );
}
