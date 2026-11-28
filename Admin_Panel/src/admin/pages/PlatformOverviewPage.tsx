import { useEffect, useState } from 'react';
import { Building2, Users, GitBranch, Receipt, TrendingUp, CreditCard, ShieldCheck, Activity } from 'lucide-react';
import { PageHeader, Btn } from '../components/layout/PageHeader';
import { StatCard } from '../components/ui/Cards';
import { formatCurrency, formatRelative } from '../utils';
import { platformAdminApi } from '../services/api';
import type { PlatformOverview } from '../types';
import { Link } from 'react-router-dom';

const EMPTY: PlatformOverview = {
  totalOrganizations: 0, activeOrganizations: 0, totalUsers: 0, totalPayments: 0,
  totalBranches: 0, verifiedPayments: 0, pendingPayments: 0, totalRevenue: 0,
  todayRevenue: 0, todayTransactions: 0, activeSubscriptions: 0, recentOrganizations: [],
};

export default function PlatformOverviewPage() {
  const [data, setData] = useState<PlatformOverview>(EMPTY);
  const [loading, setLoading] = useState(true);

  async function load() {
    try {
      setLoading(true);
      const res = await platformAdminApi.overview();
      setData(res.data);
    } catch (e) {
      console.error('Platform overview failed:', e);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => { load(); }, []);

  const s = data;

  return (
    <div className="p-4 md:p-6 space-y-6">
      <PageHeader
        title="Platform Overview"
        subtitle="SnapVerify control center — all organizations"
        actions={<Btn variant="secondary" size="sm" onClick={load}>Refresh</Btn>}
      />

      <div className="rounded-2xl p-5 border border-[rgba(184,255,59,0.2)] relative overflow-hidden"
        style={{ background: 'linear-gradient(135deg,#0D1F0A,#050D18)' }}>
        <div className="absolute top-0 right-0 w-64 h-64 rounded-full opacity-10"
          style={{ background: 'radial-gradient(circle,#B8FF3B,transparent)', transform: 'translate(30%,-30%)' }} />
        <div className="relative">
          <div className="flex items-center gap-2 mb-3">
            <span className="w-2 h-2 rounded-full bg-[#B8FF3B] animate-pulse" />
            <span className="text-[#B8FF3B] text-xs font-semibold">Platform Super Admin</span>
          </div>
          <h2 className="text-white text-2xl font-black tracking-tight mb-1">Snap<span className="text-[#B8FF3B]">Verify</span> Control Center</h2>
          <p className="text-slate-400 text-sm">Global view across every business on the platform</p>
          <div className="flex flex-wrap gap-6 mt-4">
            {[
              { label: 'Organizations', value: s.totalOrganizations, color: '#B8FF3B' },
              { label: 'Total Revenue', value: formatCurrency(s.totalRevenue), color: '#0ea5e9' },
              { label: "Today's Revenue", value: formatCurrency(s.todayRevenue), color: '#a3e635' },
            ].map(stat => (
              <div key={stat.label}>
                <p className="font-bold text-xl" style={{ color: stat.color }}>{loading ? '—' : stat.value}</p>
                <p className="text-slate-500 text-xs">{stat.label}</p>
              </div>
            ))}
          </div>
        </div>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <StatCard title="Organizations" value={s.totalOrganizations} icon={<Building2 size={20} />} iconColor="#B8FF3B" subtitle={`${s.activeOrganizations} active`} />
        <StatCard title="Total Users" value={s.totalUsers} icon={<Users size={20} />} iconColor="#38bdf8" />
        <StatCard title="Branches" value={s.totalBranches} icon={<GitBranch size={20} />} iconColor="#10b981" />
        <StatCard title="Payments" value={s.totalPayments} icon={<Receipt size={20} />} iconColor="#a3e635" />
        <StatCard title="Verified" value={s.verifiedPayments} icon={<ShieldCheck size={20} />} iconColor="#B8FF3B" />
        <StatCard title="Pending" value={s.pendingPayments} icon={<Activity size={20} />} iconColor="#fbbf24" />
        <StatCard title="Today's Revenue" value={formatCurrency(s.todayRevenue)} icon={<TrendingUp size={20} />} iconColor="#0ea5e9" />
        <StatCard title="Active Subscriptions" value={s.activeSubscriptions} icon={<CreditCard size={20} />} iconColor="#a78bfa" />
      </div>

      <div className="bg-card rounded-2xl border border-slate-800 p-5">
        <div className="flex items-center justify-between mb-4">
          <h3 className="text-white font-semibold text-sm">Recent Organizations</h3>
          <Link to="/admin/organizations" className="text-xs text-[#B8FF3B] hover:underline">View all</Link>
        </div>
        {s.recentOrganizations.length === 0 ? (
          <p className="text-slate-500 text-sm text-center py-6">No organizations yet</p>
        ) : (
          <div className="space-y-3">
            {s.recentOrganizations.map(org => (
              <div key={org.id} className="flex items-center gap-3">
                <div className="w-8 h-8 rounded-xl bg-slate-800 flex items-center justify-center flex-shrink-0">
                  <Building2 size={14} className="text-slate-400" />
                </div>
                <div className="flex-1 min-w-0">
                  <p className="text-white text-xs font-medium truncate">{org.name}</p>
                  <p className="text-slate-500 text-xs">
                    {org._count?.userAssignments ?? 0} users · {org._count?.branches ?? 0} branches
                  </p>
                </div>
                <time className="text-slate-600 text-xs flex-shrink-0">{formatRelative(org.createdAt)}</time>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}