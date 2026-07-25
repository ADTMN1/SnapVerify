import { useState, useEffect, useCallback } from 'react';
import { Building2, Plus, MapPin, Phone, Edit, Trash2, RefreshCw } from 'lucide-react';
import { PageHeader, Btn } from '../components/layout/PageHeader';
import { Modal, FormInput, ConfirmDialog } from '../components/ui/Overlays';
import { LoadingSkeleton } from '../components/ui/LoadingSkeleton';
import { formatDate } from '../utils';
import { adminDataApi, branchApi } from '../services/api';
import type { Branch } from '../types';

interface BranchWithCount extends Branch {
  _count?: { userAssignments: number; paymentAccounts: number };
}

export default function BranchesPage() {
  const [branches, setBranches] = useState<BranchWithCount[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [addOpen, setAddOpen] = useState(false);
  const [editTarget, setEditTarget] = useState<Branch | null>(null);
  const [deleteTarget, setDeleteTarget] = useState<Branch | null>(null);
  const [saving, setSaving] = useState(false);
  const [formError, setFormError] = useState('');
  const [form, setForm] = useState({ name: '', address: '', phone: '' });

  const load = useCallback(async () => {
    setLoading(true);
    setError('');
    try {
      const res = await adminDataApi.branches();
      setBranches(res.data as BranchWithCount[]);
    } catch {
      setError('Failed to load branches');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { load(); }, [load]);

  function openAdd() { setEditTarget(null); setForm({ name: '', address: '', phone: '' }); setFormError(''); setAddOpen(true); }
  function openEdit(b: Branch) { setEditTarget(b); setForm({ name: b.name, address: b.address ?? '', phone: b.phone ?? '' }); setFormError(''); setAddOpen(true); }

  async function handleSave() {
    setFormError('');
    if (!form.name.trim()) { setFormError('Branch name is required'); return; }
    setSaving(true);
    try {
      if (editTarget) {
        await branchApi.update(editTarget.id, { name: form.name, address: form.address || undefined, phone: form.phone || undefined });
      } else {
        await branchApi.create({ name: form.name, address: form.address || undefined, phone: form.phone || undefined });
      }
      setAddOpen(false);
      await load();
    } catch (err: any) {
      setFormError(err?.response?.data?.message ?? 'Failed to save branch');
    } finally {
      setSaving(false);
    }
  }

  async function handleDelete() {
    if (!deleteTarget) return;
    setSaving(true);
    try {
      await branchApi.remove(deleteTarget.id);
      setDeleteTarget(null);
      await load();
    } catch {
      setDeleteTarget(null);
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="p-4 md:p-6 space-y-6">
      <PageHeader
        title="Branch Management"
        subtitle={loading ? 'Loading…' : `${branches.length} branches`}
        actions={
          <>
            <Btn variant="secondary" size="sm" onClick={load}><RefreshCw size={14} /></Btn>
            <Btn onClick={openAdd}><Plus size={14} />Add Branch</Btn>
          </>
        }
      />

      {error && <p className="text-red-400 text-sm">{error}</p>}

      {loading ? (
        <LoadingSkeleton rows={3} />
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {branches.map(branch => (
            <div key={branch.id} className="bg-card rounded-2xl border border-slate-800 p-5 hover:border-slate-600 transition-colors">
              <div className="flex items-start justify-between mb-4">
                <div className="w-10 h-10 rounded-xl flex items-center justify-center" style={{ background: 'rgba(184,255,59,0.12)' }}>
                  <Building2 size={18} className="text-[#B8FF3B]" />
                </div>
                <div className="flex gap-1">
                  <button onClick={() => openEdit(branch)} className="p-1.5 rounded-lg text-slate-400 hover:text-white hover:bg-slate-800 transition-colors"><Edit size={14} /></button>
                  <button onClick={() => setDeleteTarget(branch)} className="p-1.5 rounded-lg text-red-400 hover:bg-red-500/10 transition-colors"><Trash2 size={14} /></button>
                </div>
              </div>
              <h3 className="text-white font-bold text-base mb-1">{branch.name}</h3>
              {branch.address && <p className="text-slate-500 text-xs flex items-center gap-1 mb-1"><MapPin size={10} />{branch.address}</p>}
              {branch.phone && <p className="text-slate-500 text-xs flex items-center gap-1 mb-3"><Phone size={10} />{branch.phone}</p>}
              <div className="grid grid-cols-2 gap-2 mt-3">
                <div className="bg-slate-900 rounded-xl p-2 text-center">
                  <p className="text-white font-bold text-sm">{branch._count?.userAssignments ?? 0}</p>
                  <p className="text-slate-600 text-xs">Staff</p>
                </div>
                <div className="bg-slate-900 rounded-xl p-2 text-center">
                  <p className="text-[#B8FF3B] font-bold text-sm">{branch._count?.paymentAccounts ?? 0}</p>
                  <p className="text-slate-600 text-xs">Accounts</p>
                </div>
              </div>
              <p className="text-slate-700 text-xs mt-3">Created {formatDate(branch.createdAt)}</p>
            </div>
          ))}
          {branches.length === 0 && <p className="text-slate-500 text-sm col-span-3 py-12 text-center">No branches yet.</p>}
        </div>
      )}

      <Modal
        open={addOpen}
        onClose={() => { setAddOpen(false); setEditTarget(null); }}
        title={editTarget ? 'Edit Branch' : 'Add Branch'}
        footer={
          <div className="flex gap-3 justify-end">
            <Btn variant="secondary" onClick={() => { setAddOpen(false); setEditTarget(null); }}>Cancel</Btn>
            <Btn onClick={handleSave} disabled={saving}>{saving ? 'Saving…' : editTarget ? 'Save Changes' : 'Create Branch'}</Btn>
          </div>
        }
      >
        <div className="space-y-4">
          {formError && <p className="text-red-400 text-sm p-3 rounded-xl bg-red-500/10">{formError}</p>}
          <FormInput label="Branch Name" value={form.name} onChange={e => setForm(f => ({ ...f, name: e.target.value }))} placeholder="Main Branch" />
          <FormInput label="Address" value={form.address} onChange={e => setForm(f => ({ ...f, address: e.target.value }))} placeholder="Bole, Addis Ababa" />
          <FormInput label="Phone" value={form.phone} onChange={e => setForm(f => ({ ...f, phone: e.target.value }))} placeholder="0911000000" />
        </div>
      </Modal>

      <ConfirmDialog
        open={!!deleteTarget}
        onClose={() => setDeleteTarget(null)}
        onConfirm={handleDelete}
        loading={saving}
        title="Delete Branch"
        message={`Delete "${deleteTarget?.name}"? All staff assignments to this branch will be unlinked.`}
        confirmLabel="Delete"
        danger
      />
    </div>
  );
}
