import { useState, useEffect, useCallback } from 'react';
import { Zap, Users, Smartphone, CreditCard, RefreshCw } from 'lucide-react';
import { PageHeader, Btn } from '../components/layout/PageHeader';
import { PageLoader } from '../components/ui/LoadingSkeleton';
import { formatDate, formatCurrency } from '../utils';
import { adminDataApi } from '../services/api';
import type { Subscription, PlatformPaymentAccount } from '../types';

const PLANS = [
  { name: 'Free', price: 0, summary: '20 verifications', color: '#64748b' },
  { name: '1 Month', price: 580, summary: 'Unlimited · 1 month', color: '#0ea5e9' },
  { name: '3 Months', price: 1500, summary: 'Unlimited · 3 months', color: '#a78bfa' },
  { name: '6 Months', price: 3000, summary: 'Unlimited · 6 months', color: '#f59e0b' },
  { name: '1 Year', price: 6000, summary: 'Unlimited · 1 year', color: '#B8FF3B' },
];

export default function SubscriptionPage() {
  const [sub, setSub] = useState<Subscription | null>(null);
  const [loading, setLoading] = useState(true);
  const [account, setAccount] = useState<PlatformPaymentAccount | null>(null);
  const [accountNumber, setAccountNumber] = useState('');
  const [accountName, setAccountName] = useState('');
  const [savingAccount, setSavingAccount] = useState(false);
  const [accountMessage, setAccountMessage] = useState('');

  const loadAccount = useCallback(async () => {
    try {
      const res = await adminDataApi.subscriptionAccount();
      setAccount(res.data ?? null);
      setAccountNumber(res.data?.accountNumber ?? '');
      setAccountName(res.data?.accountHolderName ?? '');
    } catch { /* not configured yet */ }
  }, []);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const res = await adminDataApi.subscription();
      setSub(res.data ?? null);
    } catch { /* no subscription */ }
    finally { setLoading(false); }
  }, []);

  useEffect(() => { load(); loadAccount(); }, [load, loadAccount]);

  const saveAccount = async () => {
    if (!accountNumber.trim()) {
      setAccountMessage('Enter the Telebirr account number first.');
      return;
    }
    setSavingAccount(true);
    setAccountMessage('');
    try {
      const res = await adminDataApi.updateSubscriptionAccount({
        accountNumber: accountNumber.trim(),
        accountHolderName: accountName.trim() || undefined,
      });
      setAccount(res.data ?? null);
      setAccountMessage('Subscription account saved.');
    } catch {
      setAccountMessage('Could not save the subscription account.');
    } finally {
      setSavingAccount(false);
    }
  };

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
              { label: 'Verifications This Month', value: sub.verificationLimit == null ? 'Unlimited' : `${sub.verificationUsed ?? 0} / ${sub.verificationLimit}`, icon: <Zap size={16} />, color: '#B8FF3B' },
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

      <div className="bg-card rounded-2xl border border-slate-800 p-6">
        <div className="flex items-center gap-2 mb-2">
          <CreditCard size={18} className="text-[#B8FF3B]" />
          <h3 className="text-white font-bold text-base">Telebirr Subscription Account</h3>
        </div>
        <p className="text-slate-400 text-sm">
          This is SnapVerify's own account for subscription payments. Owners see it when they upgrade.
        </p>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mt-4">
          <label className="block">
            <span className="text-slate-400 text-xs">Account number</span>
            <input
              value={accountNumber}
              onChange={(e) => setAccountNumber(e.target.value)}
              placeholder="09XXXXXXXX or 2519XXXXXXXX"
              className="mt-1 w-full rounded-xl bg-slate-900 border border-slate-800 px-3 py-2.5 text-white text-sm outline-none focus:border-[#B8FF3B]"
            />
          </label>
          <label className="block">
            <span className="text-slate-400 text-xs">Account name (optional)</span>
            <input
              value={accountName}
              onChange={(e) => setAccountName(e.target.value)}
              placeholder="SnapVerify"
              className="mt-1 w-full rounded-xl bg-slate-900 border border-slate-800 px-3 py-2.5 text-white text-sm outline-none focus:border-[#B8FF3B]"
            />
          </label>
        </div>
        <div className="flex flex-wrap items-center gap-3 mt-4">
          <button
            type="button"
            onClick={saveAccount}
            disabled={savingAccount}
            className="px-4 py-2.5 rounded-xl text-sm font-semibold bg-[#B8FF3B] text-slate-900 disabled:opacity-50"
          >
            {savingAccount ? 'Saving…' : 'Save account'}
          </button>
          {account?.isActive && (
            <span className="px-2.5 py-1 rounded-lg bg-emerald-500/10 text-emerald-400 text-xs font-semibold">
              Active
            </span>
          )}
          {accountMessage && <span className="text-slate-400 text-xs">{accountMessage}</span>}
        </div>
      </div>

      <div>
        <h3 className="text-white font-semibold text-sm mb-4">Available Plans</h3>
        <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-4 gap-4">
          {PLANS.map(plan => (
            <div key={plan.name} className="bg-card rounded-2xl border border-slate-800 p-4">
              <div className="flex items-start justify-between gap-3">
                <div>
                  <p className="text-white font-bold text-base">{plan.name}</p>
                  <p className="text-slate-400 text-sm mt-0.5">{plan.summary}</p>
                </div>
                <span className="text-xl font-black whitespace-nowrap" style={{ color: plan.color }}>
                  {plan.price === 0 ? 'Free' : formatCurrency(plan.price, 'ETB')}
                </span>
              </div>
              <button className="w-full mt-4 py-2 rounded-xl text-sm font-semibold bg-slate-800 text-slate-100 hover:bg-slate-700 transition-colors">
                Select Plan
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
