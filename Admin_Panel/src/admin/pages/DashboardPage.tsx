import { useEffect, useState } from 'react';
import { ShieldCheck, Receipt, AlertTriangle, Clock, TrendingUp, Users, Building2, CheckCircle } from 'lucide-react';
import { AreaChart, Area, BarChart, Bar, PieChart, Pie, Cell, XAxis, YAxis, Tooltip, ResponsiveContainer, Legend } from 'recharts';
import { StatCard, ChartCard } from '../components/ui/Cards';
import { StatusBadge } from '../components/ui/Badges';
import { EmployeeAvatar } from '../components/ui/Timeline';
import { formatCurrency, formatRelative } from '../utils';
import { PROVIDER_COLORS, PROVIDER_LABELS } from '../constants';
import { adminDashboardApi, type DashboardStats } from '../services/api';
import type { Payment, ActivityLog } from '../types';

const TT = { backgroundColor: '#0D1926', border: '1px solid #334155', borderRadius: 12, color: '#f1f5f9', fontSize: 12 };

const EMPTY_STATS: DashboardStats = { totalVerified: 0, totalPending: 0, totalFailed: 0, fraudAlerts: 0, todayRevenue: 0, todayTransactions: 0, activeEmployees: 0, activeBranches: 0 };

export default function DashboardPage() {
  const [stats, setStats] = useState<DashboardStats>(EMPTY_STATS);
  const [payments, setPayments] = useState<Payment[]>([]);
  const [activity, setActivity] = useState<ActivityLog[]>([]);
  const [revenueTrend, setRevenueTrend] = useState<{ date: string; value: number }[]>([]);
  const [verifyTrend, setVerifyTrend] = useState<{ date: string; verified: number; rejected: number; failed: number }[]>([]);
  const [providerStats, setProviderStats] = useState<{ provider: string; count: number }[]>([]);
  const [branchPerf, setBranchPerf] = useState<{ branchName: string; verificationRate: number; revenue: number }[]>([]);
  const [loading, setLoading] = useState(true);

  async function load() {
    try {
      setLoading(true);
      const [s, p, a, rv, vt, ps, bp] = await Promise.all([
        adminDashboardApi.stats(),
        adminDashboardApi.payments(5),
        adminDashboardApi.activity(5),
        adminDashboardApi.revenueTrend(7),
        adminDashboardApi.verificationTrend(7),
        adminDashboardApi.providerStats(),
        adminDashboardApi.branchPerformance(),
      ]);
      setStats(s.data);
      setPayments(p.data);
      setActivity(a.data);
      setRevenueTrend(rv.data);
      setVerifyTrend(vt.data);
      setProviderStats(ps.data);
      setBranchPerf(bp.data);
    } catch (e) {
      console.error('Dashboard load failed:', e);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    load();
    const t = setInterval(load, 30000);
    return () => clearInterval(t);
  }, []);

  const s = stats;

  if (loading && s.totalVerified === 0) {
    return (
      <div className="p-4 md:p-6 space-y-6">
        <div className="rounded-2xl p-5 border border-slate-800 bg-slate-900/50 animate-pulse h-32" />
        <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
          {Array.from({ length: 8 }).map((_, i) => (
            <div key={i} className="rounded-2xl p-4 bg-slate-900/50 border border-slate-800 h-24 animate-pulse" />
          ))}
        </div>
      </div>
    );
  }

  return (
    <div className="p-4 md:p-6 space-y-6">
      {/* Hero */}
      <div className="rounded-2xl p-5 border border-[rgba(184,255,59,0.2)] relative overflow-hidden" style={{ background: 'linear-gradient(135deg,#0D1F0A,#050D18)' }}>
        <div className="absolute top-0 right-0 w-64 h-64 rounded-full opacity-10" style={{ background: 'radial-gradient(circle,#B8FF3B,transparent)', transform: 'translate(30%,-30%)' }} />
        <div className="relative">
          <div className="flex items-center gap-2 mb-3">
            <span className="w-2 h-2 rounded-full bg-[#B8FF3B] animate-pulse" />
            <span className="text-[#B8FF3B] text-xs font-semibold">System Operational</span>
          </div>
          <h2 className="text-white text-2xl font-black tracking-tight mb-1">Snap<span className="text-[#B8FF3B]">Verify</span> Dashboard</h2>
          <p className="text-slate-400 text-sm">Real-time payment verification & fraud prevention</p>
          <div className="flex gap-6 mt-4">
            {[
              { label: 'Transactions Today', value: s.todayTransactions, color: '#B8FF3B' },
              { label: "Today's Revenue", value: formatCurrency(s.todayRevenue), color: '#0ea5e9' },
              { label: 'Active Branches', value: s.activeBranches, color: '#a3e635' },
            ].map(stat => (
              <div key={stat.label}>
                <p className="font-bold text-xl" style={{ color: stat.color }}>{stat.value}</p>
                <p className="text-slate-500 text-xs">{stat.label}</p>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Stat Cards */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <StatCard title="Total Verified" value={s.totalVerified} icon={<CheckCircle size={20} />} iconColor="#B8FF3B" />
        <StatCard title="Pending" value={s.totalPending} icon={<Clock size={20} />} iconColor="#fbbf24" />
        <StatCard title="Failed / Rejected" value={s.totalFailed} icon={<AlertTriangle size={20} />} iconColor="#ef4444" />
        <StatCard title="Fraud Alerts" value={s.fraudAlerts} icon={<ShieldCheck size={20} />} iconColor="#a78bfa" />
        <StatCard title="Today's Revenue" value={formatCurrency(s.todayRevenue)} icon={<TrendingUp size={20} />} iconColor="#0ea5e9" />
        <StatCard title="Transactions Today" value={s.todayTransactions} icon={<Receipt size={20} />} iconColor="#a3e635" />
        <StatCard title="Active Employees" value={s.activeEmployees} icon={<Users size={20} />} iconColor="#38bdf8" />
        <StatCard title="Active Branches" value={s.activeBranches} icon={<Building2 size={20} />} iconColor="#10b981" />
      </div>

      {/* Charts Row 1 */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <ChartCard title="Revenue (Last 7 Days)" subtitle="ETB">
          <ResponsiveContainer width="100%" height={200}>
            <AreaChart data={revenueTrend}>
              <defs>
                <linearGradient id="rev" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="#B8FF3B" stopOpacity={0.3} />
                  <stop offset="95%" stopColor="#B8FF3B" stopOpacity={0} />
                </linearGradient>
              </defs>
              <XAxis dataKey="date" tick={{ fill: '#64748b', fontSize: 11 }} tickFormatter={d => d.slice(5)} axisLine={false} tickLine={false} />
              <YAxis tick={{ fill: '#64748b', fontSize: 11 }} axisLine={false} tickLine={false} tickFormatter={v => `${(v / 1000).toFixed(0)}k`} />
              <Tooltip contentStyle={TT} formatter={(v) => [formatCurrency(Number(v ?? 0)), 'Revenue']} />
              <Area type="monotone" dataKey="value" stroke="#B8FF3B" strokeWidth={2} fill="url(#rev)" />
            </AreaChart>
          </ResponsiveContainer>
        </ChartCard>

        <ChartCard title="Verification Trend" subtitle="Last 7 days">
          <ResponsiveContainer width="100%" height={200}>
            <BarChart data={verifyTrend} barSize={8}>
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
      </div>

      {/* Charts Row 2 */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
        <ChartCard title="Payment Providers" subtitle="By verification count">
          <ResponsiveContainer width="100%" height={200}>
            <PieChart>
              <Pie data={providerStats} dataKey="count" nameKey="provider" cx="50%" cy="50%" outerRadius={75} innerRadius={45}>
                {providerStats.map(entry => (
                  <Cell key={entry.provider} fill={PROVIDER_COLORS[entry.provider as keyof typeof PROVIDER_COLORS] ?? '#64748b'} />
                ))}
              </Pie>
              <Tooltip contentStyle={TT} formatter={(v, name) => [v, PROVIDER_LABELS[name as keyof typeof PROVIDER_LABELS] ?? name]} />
              <Legend wrapperStyle={{ fontSize: 11, color: '#94a3b8' }} formatter={v => PROVIDER_LABELS[v as keyof typeof PROVIDER_LABELS] ?? v} />
            </PieChart>
          </ResponsiveContainer>
        </ChartCard>

        <ChartCard title="Branch Performance" subtitle="Verification rate %" className="lg:col-span-2">
          <ResponsiveContainer width="100%" height={200}>
            <BarChart data={branchPerf} layout="vertical" barSize={10}>
              <XAxis type="number" tick={{ fill: '#64748b', fontSize: 11 }} axisLine={false} tickLine={false} unit="%" />
              <YAxis type="category" dataKey="branchName" tick={{ fill: '#94a3b8', fontSize: 11 }} axisLine={false} tickLine={false} width={120} />
              <Tooltip contentStyle={TT} formatter={(v) => [`${Number(v).toFixed(1)}%`, 'Rate']} />
              <Bar dataKey="verificationRate" fill="#B8FF3B" radius={[0, 4, 4, 0]} name="Rate %" />
            </BarChart>
          </ResponsiveContainer>
        </ChartCard>
      </div>

      {/* Bottom */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <div className="bg-card rounded-2xl border border-slate-800 p-5">
          <h3 className="text-white font-semibold text-sm mb-4">Recent Transactions</h3>
          {payments.length === 0 ? (
            <p className="text-slate-500 text-sm text-center py-6">No transactions yet</p>
          ) : (
            <div className="space-y-3">
              {payments.map(p => (
                <div key={p.id} className="flex items-center gap-3">
                  <div className="w-8 h-8 rounded-xl bg-slate-800 flex items-center justify-center flex-shrink-0">
                    <Receipt size={14} className="text-slate-400" />
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-white text-xs font-medium truncate">{p.senderName ?? 'Unknown'}</p>
                    <p className="text-slate-500 text-xs">{p.transactionId}</p>
                  </div>
                  <div className="text-right flex-shrink-0">
                    <p className="text-white text-xs font-semibold">{formatCurrency(p.amount)}</p>
                    <StatusBadge status={p.status} />
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>

        <div className="bg-card rounded-2xl border border-slate-800 p-5">
          <h3 className="text-white font-semibold text-sm mb-4">Recent Activity</h3>
          {activity.length === 0 ? (
            <p className="text-slate-500 text-sm text-center py-6">No recent activity</p>
          ) : (
            <div className="space-y-3">
              {activity.map(log => (
                <div key={log.id} className="flex items-center gap-3">
                  <EmployeeAvatar name={log.user?.fullName} id={log.userId ?? ''} size="sm" />
                  <div className="flex-1 min-w-0">
                    <p className="text-white text-xs font-medium truncate">{log.user?.fullName ?? 'System'}</p>
                    <p className="text-slate-500 text-xs">{log.action.replace(/_/g, ' ')}</p>
                  </div>
                  <time className="text-slate-600 text-xs flex-shrink-0">{formatRelative(log.createdAt)}</time>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
