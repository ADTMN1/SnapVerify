import { useState, useEffect, useCallback } from 'react';
import axios from 'axios';
import { RefreshCw, Plus, Edit, Eye, EyeOff } from 'lucide-react';
import { PageHeader, Btn } from '../components/layout/PageHeader';
import { DataTable } from '../components/ui/DataTable';
import { Modal, FormInput, FormSelect, ConfirmDialog } from '../components/ui/Overlays';
import { LoadingSkeleton } from '../components/ui/LoadingSkeleton';
import { platformAdminApi } from '../services/api';
import type { SubscriptionPlan, TableColumn } from '../types';

type DurationMode = 'months' | 'days' | 'lifetime';

interface PlanForm {
  name: string;
  price: string;
  durationMode: DurationMode;
  durationValue: string;
}

function durationLabel(plan: SubscriptionPlan): string {
  if (plan.isLifetime || (plan.durationMonths == null && plan.durationDays == null)) {
    return 'No expiry';
  }
  if (plan.durationMonths != null) {
    return plan.durationMonths === 1
      ? '1 month'
      : `${plan.durationMonths} months`;
  }
  const days = plan.durationDays ?? 0;
  return days === 1 ? '1 day' : `${days} days`;
}

function formFromPlan(plan?: SubscriptionPlan): PlanForm {
  if (!plan) {
    return { name: '', price: '', durationMode: 'months', durationValue: '' };
  }
  if (plan.isLifetime || (plan.durationMonths == null && plan.durationDays == null)) {
    return { name: plan.name, price: String(plan.price), durationMode: 'lifetime', durationValue: '' };
  }
  if (plan.durationMonths != null) {
    return { name: plan.name, price: String(plan.price), durationMode: 'months', durationValue: String(plan.durationMonths) };
  }
  return { name: plan.name, price: String(plan.price), durationMode: 'days', durationValue: String(plan.durationDays) };
}

function apiMessage(err: unknown, fallback: string): string {
  if (axios.isAxiosError<{ message?: string }>(err)) {
    return err.response?.data?.message ?? fallback;
  }
  return err instanceof Error && err.message ? err.message : fallback;
}

export default function PlatformPlansPage() {
  const [rows, setRows] = useState<SubscriptionPlan[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [open, setOpen] = useState(false);
  const [editing, setEditing] = useState<SubscriptionPlan | null>(null);
  const [visibilityTarget, setVisibilityTarget] = useState<SubscriptionPlan | null>(null);
  const [saving, setSaving] = useState(false);
  const [togglingVisibility, setTogglingVisibility] = useState(false);
  const [formError, setFormError] = useState('');
  const [form, setForm] = useState<PlanForm>(formFromPlan());

  const load = useCallback(async () => {
    setLoading(true); setError('');
    try {
      const res = await platformAdminApi.plans();
      setRows(res.data);
    } catch { setError('Failed to load plans'); }
    finally { setLoading(false); }
  }, []);

  useEffect(() => { void Promise.resolve().then(load); }, [load]);

  function openAdd() {
    setEditing(null);
    setForm(formFromPlan());
    setFormError(''); setOpen(true);
  }
  function openEdit(plan: SubscriptionPlan) {
    setEditing(plan);
    setForm(formFromPlan(plan));
    setFormError(''); setOpen(true);
  }

  async function handleSave() {
    setFormError('');
    const price = Number(form.price);
    if (!form.name.trim()) { setFormError('Name is required'); return; }
    if (!Number.isFinite(price) || price < 0) { setFormError('Enter a valid price'); return; }

    let duration: Partial<SubscriptionPlan>;
    if (form.durationMode === 'lifetime') {
      duration = { durationDays: null, durationMonths: null, isLifetime: true };
    } else {
      const value = Number(form.durationValue);
      const unit = form.durationMode === 'months' ? 'months' : 'days';
      if (!Number.isInteger(value) || value <= 0) {
        setFormError(`Enter a valid number of ${unit}`);
        return;
      }
      duration = form.durationMode === 'months'
        ? { durationDays: null, durationMonths: value, isLifetime: false }
        : { durationDays: value, durationMonths: null, isLifetime: false };
    }

    setSaving(true);
    try {
      if (editing) {
        await platformAdminApi.updatePlan(editing.id, {
          name: form.name.trim(),
          price,
          ...duration,
        });
      } else {
        await platformAdminApi.createPlan({
          name: form.name.trim(),
          price,
          ...duration,
        });
      }
      setOpen(false);
      await load();
    } catch (err) {
      setFormError(apiMessage(err, 'Failed to save plan'));
    } finally { setSaving(false); }
  }

  async function handleVisibilityChange() {
    if (!visibilityTarget) return;
    const nextIsActive = !visibilityTarget.isActive;
    setError('');
    setTogglingVisibility(true);
    try {
      await platformAdminApi.updatePlan(visibilityTarget.id, { isActive: nextIsActive });
      setVisibilityTarget(null);
      await load();
    } catch (err) {
      setError(apiMessage(err, nextIsActive ? 'Failed to restore plan' : 'Failed to hide plan'));
      setVisibilityTarget(null);
    } finally {
      setTogglingVisibility(false);
    }
  }

  const columns: TableColumn<SubscriptionPlan>[] = [
    { key: 'name', label: 'Plan', sortable: true },
    { key: 'price', label: 'Price', sortable: true, render: (_v, r) => `${r.price} ${r.currency}` },
    { key: 'durationMonths', label: 'Duration', render: (_v, r) => durationLabel(r) },
    { key: 'verificationLimit', label: 'Verifications', render: v => (v == null ? 'Unlimited' : String(v)) },
    {
      key: 'isActive', label: 'Status', render: v =>
        v ? <span style={{ color: '#B8FF3B' }}>Active</span> : <span className="text-red-400">Hidden</span>,
    },
    {
      key: 'id', label: '', render: (_v, r) => (
        <div className="flex items-center gap-1">
          <button
            onClick={() => openEdit(r)}
            disabled={togglingVisibility}
            aria-label={`Edit ${r.name}`}
            title="Edit plan"
            className="p-1.5 rounded-lg text-slate-400 hover:text-white hover:bg-slate-800 transition-colors disabled:opacity-40 disabled:cursor-not-allowed"
          >
            <Edit size={14} />
          </button>
          <button
            onClick={() => setVisibilityTarget(r)}
            disabled={togglingVisibility}
            aria-label={r.isActive ? `Hide ${r.name}` : `Restore ${r.name}`}
            title={r.isActive ? 'Hide plan' : 'Restore plan'}
            className={`p-1.5 rounded-lg transition-colors disabled:opacity-40 disabled:cursor-not-allowed ${
              r.isActive
                ? 'text-slate-400 hover:text-red-400 hover:bg-red-500/10'
                : 'text-[#B8FF3B] hover:bg-slate-800'
            }`}
          >
            {r.isActive ? <EyeOff size={14} /> : <Eye size={14} />}
          </button>
        </div>
      ),
    },
  ];

  return (
    <div className="p-4 md:p-6 space-y-6">
      <PageHeader
        title="Subscription Plans"
        subtitle={loading ? 'Loading plans…' : `${rows.filter(p => p.isActive).length} visible · ${rows.filter(p => !p.isActive).length} hidden — changes reflect in the SnapVerify app`}
        actions={
          <>
            <Btn variant="secondary" size="sm" onClick={load}><RefreshCw size={14} /></Btn>
            <Btn onClick={openAdd}><Plus size={14} />Add Plan</Btn>
          </>
        }
      />
      {error && <p className="text-red-400 text-sm">{error}</p>}
      {loading ? <LoadingSkeleton rows={4} /> : (
        <DataTable columns={columns} data={rows} loading={loading} emptyMessage="No plans found" />
      )}

      <Modal open={open} onClose={() => setOpen(false)} title={editing ? 'Edit Plan' : 'Add Plan'}
        footer={
          <div className="flex gap-3 justify-end">
            <Btn variant="secondary" onClick={() => setOpen(false)}>Cancel</Btn>
            <Btn onClick={handleSave} disabled={saving}>{saving ? 'Saving…' : 'Save'}</Btn>
          </div>
        }
      >
        <div className="space-y-4">
          {formError && <p className="text-red-400 text-sm p-3 rounded-xl bg-red-500/10">{formError}</p>}
          <FormInput label="Plan Name" value={form.name} onChange={e => setForm(f => ({ ...f, name: e.target.value }))} placeholder="e.g. 5 Months" />
          <FormInput label="Price (ETB)" value={form.price} onChange={e => setForm(f => ({ ...f, price: e.target.value }))} placeholder="e.g. 60000" />
          <FormSelect
            label="Duration Type"
            value={form.durationMode}
            onChange={e => setForm(f => ({ ...f, durationMode: e.target.value as DurationMode, durationValue: '' }))}
          >
            <option value="months">Months</option>
            <option value="days">Days</option>
            <option value="lifetime">Lifetime (no expiry)</option>
          </FormSelect>
          {form.durationMode !== 'lifetime' && (
            <FormInput
              label={form.durationMode === 'months' ? 'Duration (months)' : 'Duration (days)'}
              type="number"
              min="1"
              step="1"
              value={form.durationValue}
              onChange={e => setForm(f => ({ ...f, durationValue: e.target.value }))}
              placeholder={form.durationMode === 'months' ? 'e.g. 5' : 'e.g. 30'}
            />
          )}
        </div>
      </Modal>

      <ConfirmDialog
        open={!!visibilityTarget}
        onClose={() => setVisibilityTarget(null)}
        onConfirm={handleVisibilityChange}
        loading={togglingVisibility}
        title={visibilityTarget?.isActive ? 'Hide Plan' : 'Restore Plan'}
        message={
          visibilityTarget?.isActive
            ? `Hide "${visibilityTarget?.name}"? Customers will no longer see it or start new purchases. Existing subscriptions and payment records are not deleted.`
            : `Restore "${visibilityTarget?.name}"? Customers will see it again and will be able to purchase it.`
        }
        confirmLabel={visibilityTarget?.isActive ? 'Hide' : 'Restore'}
        danger={!!visibilityTarget?.isActive}
      />
    </div>
  );
}
