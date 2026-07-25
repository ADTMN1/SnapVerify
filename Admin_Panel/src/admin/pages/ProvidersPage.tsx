import { useState, useEffect, useCallback } from 'react';
import { CheckCircle, XCircle, Plus, Trash2, Edit, RefreshCw } from 'lucide-react';
import { PageHeader, Btn } from '../components/layout/PageHeader';
import { ProviderBadge } from '../components/ui/Badges';
import { Modal, FormInput, FormSelect, ConfirmDialog } from '../components/ui/Overlays';
import { LoadingSkeleton } from '../components/ui/LoadingSkeleton';
import { PROVIDER_LABELS, PROVIDER_COLORS } from '../constants';
import { adminDataApi, paymentAccountApi } from '../services/api';
import type { PaymentAccount, PaymentProvider } from '../types';

const PROVIDERS = Object.keys(PROVIDER_LABELS) as PaymentProvider[];

export default function ProvidersPage() {
  const [accounts, setAccounts] = useState<PaymentAccount[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [addOpen, setAddOpen] = useState(false);
  const [editTarget, setEditTarget] = useState<PaymentAccount | null>(null);
  const [deleteTarget, setDeleteTarget] = useState<PaymentAccount | null>(null);
  const [saving, setSaving] = useState(false);
  const [formError, setFormError] = useState('');
  const [form, setForm] = useState({ provider: 'CBE', accountNumber: '', suffix: '', accountHolderName: '' });

  const load = useCallback(async () => {
    setLoading(true); setError('');
    try {
      const res = await adminDataApi.paymentAccounts();
      setAccounts(res.data);
    } catch { setError('Failed to load payment accounts'); }
    finally { setLoading(false); }
  }, []);

  useEffect(() => { load(); }, [load]);

  function openAdd() {
    setEditTarget(null);
    setForm({ provider: 'CBE', accountNumber: '', suffix: '', accountHolderName: '' });
    setFormError(''); setAddOpen(true);
  }
  function openEdit(acc: PaymentAccount) {
    setEditTarget(acc);
    setForm({ provider: acc.provider, accountNumber: acc.accountNumber ?? '', suffix: acc.suffix ?? '', accountHolderName: acc.accountHolderName ?? '' });
    setFormError(''); setAddOpen(true);
  }

  async function handleSave() {
    setFormError('');
    setSaving(true);
    try {
      const data = { provider: form.provider as PaymentProvider, accountNumber: form.accountNumber || undefined, suffix: form.suffix || undefined, accountHolderName: form.accountHolderName || undefined };
      if (editTarget) {
        await paymentAccountApi.update(form.provider, data);
      } else {
        await paymentAccountApi.create(data);
      }
      setAddOpen(false);
      await load();
    } catch (err: any) {
      setFormError(err?.response?.data?.message ?? 'Failed to save account');
    } finally { setSaving(false); }
  }

  async function handleDelete() {
    if (!deleteTarget) return;
    setSaving(true);
    try {
      await paymentAccountApi.remove(deleteTarget.provider);
      setDeleteTarget(null);
      await load();
    } catch { setDeleteTarget(null); }
    finally { setSaving(false); }
  }

  return (
    <div className="p-4 md:p-6 space-y-6">
      <PageHeader
        title="Payment Providers"
        subtitle="Manage registered payment accounts"
        actions={
          <>
            <Btn variant="secondary" size="sm" onClick={load}><RefreshCw size={14} /></Btn>
            <Btn onClick={openAdd}><Plus size={14} />Add Account</Btn>
          </>
        }
      />
      {error && <p className="text-red-400 text-sm">{error}</p>}
      {loading ? <LoadingSkeleton rows={3} /> : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {accounts.map(acc => {
            const color = PROVIDER_COLORS[acc.provider];
            return (
              <div key={acc.id} className="bg-card rounded-2xl border border-slate-800 p-5">
                <div className="flex items-start justify-between mb-4">
                  <div className="w-10 h-10 rounded-xl flex items-center justify-center" style={{ background: `${color}20` }}>
                    <span className="font-bold text-xs" style={{ color }}>{acc.provider.slice(0, 2)}</span>
                  </div>
                  <div className="flex items-center gap-2">
                    {acc.isActive ? <CheckCircle size={16} className="text-[#B8FF3B]" /> : <XCircle size={16} className="text-red-400" />}
                    <span className="text-xs font-medium" style={{ color: acc.isActive ? '#B8FF3B' : '#ef4444' }}>{acc.isActive ? 'Active' : 'Inactive'}</span>
                  </div>
                </div>
                <ProviderBadge provider={acc.provider} />
                <div className="mt-3 space-y-1">
                  {acc.accountNumber && <p className="text-slate-400 text-xs font-mono">Acc: {acc.accountNumber}</p>}
                  {acc.suffix && <p className="text-slate-400 text-xs font-mono">Suffix: {acc.suffix}</p>}
                  {acc.accountHolderName && <p className="text-slate-500 text-xs">{acc.accountHolderName}</p>}
                  {acc.branch && <p className="text-slate-600 text-xs">Branch: {acc.branch.name}</p>}
                </div>
                <div className="flex gap-2 mt-4">
                  <button onClick={() => openEdit(acc)} className="p-1.5 rounded-lg text-slate-400 hover:text-white hover:bg-slate-800 transition-colors"><Edit size={14} /></button>
                  <button onClick={() => setDeleteTarget(acc)} className="p-1.5 rounded-lg text-red-400 hover:bg-red-500/10 transition-colors"><Trash2 size={14} /></button>
                </div>
              </div>
            );
          })}
          {accounts.length === 0 && <p className="text-slate-500 text-sm col-span-3 py-12 text-center">No payment accounts registered yet.</p>}
        </div>
      )}

      <Modal open={addOpen} onClose={() => setAddOpen(false)} title={editTarget ? 'Edit Payment Account' : 'Add Payment Account'}
        footer={
          <div className="flex gap-3 justify-end">
            <Btn variant="secondary" onClick={() => setAddOpen(false)}>Cancel</Btn>
            <Btn onClick={handleSave} disabled={saving}>{saving ? 'Saving…' : 'Save'}</Btn>
          </div>
        }
      >
        <div className="space-y-4">
          {formError && <p className="text-red-400 text-sm p-3 rounded-xl bg-red-500/10">{formError}</p>}
          <FormSelect label="Provider" value={form.provider} onChange={e => setForm(f => ({ ...f, provider: e.target.value }))} disabled={!!editTarget}>
            {PROVIDERS.map(p => <option key={p} value={p}>{PROVIDER_LABELS[p]}</option>)}
          </FormSelect>
          <FormInput label="Account Number" value={form.accountNumber} onChange={e => setForm(f => ({ ...f, accountNumber: e.target.value }))} placeholder="Optional" />
          <FormInput label="Suffix" value={form.suffix} onChange={e => setForm(f => ({ ...f, suffix: e.target.value }))} placeholder="CBE: 8 digits, Abyssinia: 5 digits" />
          <FormInput label="Account Holder Name" value={form.accountHolderName} onChange={e => setForm(f => ({ ...f, accountHolderName: e.target.value }))} placeholder="Business name on account" />
        </div>
      </Modal>

      <ConfirmDialog open={!!deleteTarget} onClose={() => setDeleteTarget(null)} onConfirm={handleDelete} loading={saving}
        title="Remove Account" message="Remove this payment account? Payments to this account will no longer be verified." confirmLabel="Remove" danger />
    </div>
  );
}
