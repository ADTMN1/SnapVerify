import { useState, useEffect, useCallback } from 'react';
import { Zap, CheckCircle, Users, Smartphone, CreditCard, RefreshCw } from 'lucide-react';
import { PageHeader, Btn } from '../components/layout/PageHeader';
import { PageLoader } from '../components/ui/LoadingSkeleton';
import { formatDate, formatCurrency } from '../utils';
import { adminDataApi } from '../services/api';
import type { Subscription } from '../types';

const PLANS = [
  { name: 'Starter', price: 499, color: '#0ea5e9', popular: false,
    features: ['Up to 10 staff', 'Up to 20 devices', '3 branches', 'Basic reports'] },
  { name: 'Business', price: 999, color: '#B8FF3B', popular: true,
    features: ['Up to 30 staff', 'Up to 50 devices', 'Unlimited branches', 'Advanced analytics', 'Fraud detection'] },
  { name: 'Enterprise', price: 2499, color: '#a78bfa', popular: false,
    features: ['Unlimited staff & devices', 'Unlimited branches', 'Custom integrations', 'Dedicated support', 'SLA'] },
];

export default function SubscriptionPage() {
  const [sub, setSub] = useState<Subscription | null>(null);
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const res = await adminDataApi.subscription();
      setSub(res.data ?? null);
    } catch { /* no subscription */ }
    finally { setLoading(false); }
  }, []);

  useEffect(() => { load(); }, [load]);

  if (loading) return <PageLoader />;

  const daysLeft = sub?.endDate ? Math.max(0, Math.ceil((new Date(sub.endDate).getTime() - Date.now()) / 86400000)) : null;

  return (
    <div className="p-4 md:p-6 space-y-6">
      <PageHeader title="Subscription & Billing" subtitle="Manage your plan"
        actions={<button onClick={load} className="p-2 rounded-xl text-slate-400 hover:text-white hover:bg-slate-800 transition-colors"><RefreshCw size={16} /></button>} />

      {sub ? (
        <div className="bg-card rounded-2xl border border-slate-800 p-6">
          <div className="flex items-start justify-between flex-wrap gap-4">
            <div>
              <div className="flex items-center gap-2 mb-2">
                <Zap size={18} className="text-[#B8FF3B]" />
                <h3 className="text-white font-bold text-lg capitalize">{sub.planName.replace(/_/g, ' ')}</h3>
                <span className="px-2.5 py-1 rounded-lg text-xs font-semibold" style={{ background: 'rgba(184,255,59,0.12)', color: '#B8FF3B' }}>{sub.status}</span>
              </div>
              <p className="text-slate-400 text-sm">Started {formatDate(sub.startDate)}</p>
              {sub.endDate && <p className="text-slate-400 text-sm">Valid until {formatDate(sub.endDate)}</p>}
              {daysLeft !== null && daysLeft <= 7 && (
                <p className="text-amber-400 text-sm font-semibold mt-1">⚠ {daysLeft} days remaining — upgrade to continue.</p>
              )}
            </div>
            <Btn>Upgrade Plan</Btn>
          </div>
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 mt-6">
            {[
              { label: 'Max Staff', value: sub.maxUsers, icon: <Users size={16} />, color: '#0ea5e9' },
              { label: 'Max Devices', value: sub.maxDevices, icon: <Smartphone size={16} />, color: '#a78bfa' },
            ].map(u => (
              <div key={u.label} className="bg-slate-900 rounded-xl p-4 flex items-center gap-3">
                <div style={{ color: u.color }}>{u.icon}</div>
                <div>
                  <p className="text-slate-400 text-xs">{u.label}</p>
                  <p className="text-white font-bold">{u.value ?? 'Unlimited'}</p>
                </div>
              </div>
            ))}
          </div>
        </div>
      ) : (
        <div className="bg-card rounded-2xl border border-slate-800 p-8 text-center">
          <p className="text-slate-400 text-sm">No active subscription found.</p>
        </div>
      )}

      <div>
        <h3 className="text-white font-semibold text-sm mb-4">Available Plans</h3>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          {PLANS.map(plan => (
            <div key={plan.name} className="bg-card rounded-2xl border p-5 relative"
              style={{ borderColor: plan.popular ? `${plan.color}60` : '#1e293b' }}>
              {plan.popular && (
                <div className="absolute -top-3 left-1/2 -translate-x-1/2 px-3 py-1 rounded-full text-xs font-bold text-slate-900"
                  style={{ background: plan.color }}>Most Popular</div>
              )}
              <p className="text-white font-bold text-base">{plan.name}</p>
              <div className="flex items-baseline gap-1 mt-1 mb-4">
                <span className="text-2xl font-black" style={{ color: plan.color }}>{formatCurrency(plan.price, 'ETB')}</span>
                <span className="text-slate-500 text-xs">/month</span>
              </div>
              <ul className="space-y-2 mb-5">
                {plan.features.map(f => (
                  <li key={f} className="flex items-center gap-2 text-slate-300 text-sm">
                    <CheckCircle size={13} style={{ color: plan.color, flexShrink: 0 }} />{f}
                  </li>
                ))}
              </ul>
              <button className="w-full py-2.5 rounded-xl text-sm font-semibold transition-all hover:opacity-90"
                style={plan.popular ? { background: plan.color, color: '#0f172a' } : { background: '#1e293b', color: '#f1f5f9' }}>
                {plan.popular ? 'Upgrade Now' : 'Select Plan'}
              </button>
            </div>
          ))}
        </div>
      </div>

      <div className="bg-card rounded-2xl border border-slate-800 overflow-hidden">
        <div className="px-5 py-4 border-b border-slate-800 flex items-center gap-2">
          <CreditCard size={16} className="text-slate-400" />
          <h3 className="text-white font-semibold text-sm">Billing History</h3>
        </div>
        <div className="py-8 text-center">
          <p className="text-slate-500 text-sm">
            {/* TODO: billing history requires a dedicated invoices endpoint */}
            Billing history will appear here once invoice tracking is implemented.
          </p>
        </div>
      </div>
    </div>
  );
}
