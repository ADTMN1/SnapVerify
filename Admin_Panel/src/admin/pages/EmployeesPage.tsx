import { useState, useEffect, useCallback } from 'react';
import { UserPlus, Eye, Trash2, Phone, RefreshCw } from 'lucide-react';
import { PageHeader, Btn } from '../components/layout/PageHeader';
import { RoleBadge, ActiveBadge } from '../components/ui/Badges';
import { EmployeeAvatar } from '../components/ui/Timeline';
import { Drawer, Modal, FormInput, FormSelect, ConfirmDialog } from '../components/ui/Overlays';
import { LoadingSkeleton } from '../components/ui/LoadingSkeleton';
import { formatDate, formatPhone } from '../utils';
import { adminDataApi, staffApi } from '../services/api';
import type { UserBusinessAssignment } from '../types';

export default function EmployeesPage() {
  const [staff, setStaff] = useState<UserBusinessAssignment[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [selected, setSelected] = useState<UserBusinessAssignment | null>(null);
  const [addOpen, setAddOpen] = useState(false);
  const [deleteTarget, setDeleteTarget] = useState<UserBusinessAssignment | null>(null);
  const [saving, setSaving] = useState(false);
  const [form, setForm] = useState({ fullName: '', phone: '', role: 'CASHIER', password: '' });
  const [formError, setFormError] = useState('');

  const load = useCallback(async () => {
    setLoading(true);
    setError('');
    try {
      const res = await adminDataApi.staff();
      setStaff(res.data);
    } catch {
      setError('Failed to load staff');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { load(); }, [load]);

  async function handleAdd() {
    setFormError('');
    if (!form.fullName || !form.phone || !form.password) {
      setFormError('Full name, phone, and password are required');
      return;
    }
    setSaving(true);
    try {
      await staffApi.add(form);
      setAddOpen(false);
      setForm({ fullName: '', phone: '', role: 'CASHIER', password: '' });
      await load();
    } catch (err: any) {
      setFormError(err?.response?.data?.message ?? 'Failed to add staff');
    } finally {
      setSaving(false);
    }
  }

  async function handleDelete() {
    if (!deleteTarget) return;
    setSaving(true);
    try {
      await staffApi.remove(deleteTarget.id);
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
        title="Employees"
        subtitle={loading ? 'Loading…' : `${staff.length} staff members`}
        actions={
          <>
            <Btn variant="secondary" size="sm" onClick={load}><RefreshCw size={14} /></Btn>
            <Btn onClick={() => setAddOpen(true)}><UserPlus size={14} />Add Staff</Btn>
          </>
        }
      />

      {error && <p className="text-red-400 text-sm">{error}</p>}

      {loading ? (
        <LoadingSkeleton rows={6} />
      ) : (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
          {staff.map(s => (
            <div key={s.id} className="bg-card rounded-2xl border border-slate-800 p-5 hover:border-slate-600 transition-colors">
              <div className="flex items-start justify-between mb-4">
                <div className="flex items-center gap-3">
                  <EmployeeAvatar name={s.user?.fullName} id={s.userId} size="lg" />
                  <div>
                    <p className="text-white font-semibold text-sm">{s.user?.fullName ?? '—'}</p>
                    <p className="text-slate-500 text-xs flex items-center gap-1"><Phone size={10} />{formatPhone(s.user?.phone ?? '')}</p>
                  </div>
                </div>
                <ActiveBadge active={s.status === 'active'} />
              </div>
              <div className="flex items-center justify-between">
                <div className="flex gap-2 flex-wrap">
                  <RoleBadge role={s.role} />
                  {s.branch && <span className="text-slate-500 text-xs self-center">{s.branch.name}</span>}
                </div>
                <div className="flex gap-1">
                  <button onClick={() => setSelected(s)} className="p-1.5 rounded-lg text-slate-400 hover:text-white hover:bg-slate-800 transition-colors"><Eye size={14} /></button>
                  {s.role !== 'OWNER' && (
                    <button onClick={() => setDeleteTarget(s)} className="p-1.5 rounded-lg text-red-400 hover:bg-red-500/10 transition-colors"><Trash2 size={14} /></button>
                  )}
                </div>
              </div>
              <p className="text-slate-600 text-xs mt-3">Joined {formatDate(s.createdAt)}</p>
            </div>
          ))}
          {staff.length === 0 && !loading && (
            <p className="text-slate-500 text-sm col-span-3 py-12 text-center">No staff members yet. Add your first employee.</p>
          )}
        </div>
      )}

      <Drawer open={!!selected} onClose={() => setSelected(null)} title="Employee Details">
        {selected && (
          <div className="p-6 space-y-6">
            <div className="flex items-center gap-4">
              <EmployeeAvatar name={selected.user?.fullName} id={selected.userId} size="lg" />
              <div>
                <p className="text-white font-bold text-lg">{selected.user?.fullName ?? '—'}</p>
                <p className="text-slate-400 text-sm">{formatPhone(selected.user?.phone ?? '')}</p>
                {selected.user?.email && <p className="text-slate-500 text-xs">{selected.user.email}</p>}
                <div className="flex gap-2 mt-2"><RoleBadge role={selected.role} /><ActiveBadge active={selected.status === 'active'} /></div>
              </div>
            </div>
            <div className="space-y-2">
              {[
                { label: 'Branch', value: selected.branch?.name ?? 'All Branches' },
                { label: 'Joined', value: formatDate(selected.createdAt) },
                { label: 'Last Updated', value: formatDate(selected.updatedAt) },
                { label: 'Status', value: selected.status },
              ].map(i => (
                <div key={i.label} className="flex justify-between py-2 border-b border-slate-800">
                  <span className="text-slate-500 text-sm">{i.label}</span>
                  <span className="text-white text-sm font-medium">{i.value}</span>
                </div>
              ))}
            </div>
          </div>
        )}
      </Drawer>

      <Modal open={addOpen} onClose={() => { setAddOpen(false); setFormError(''); }} title="Add Staff Member"
        footer={
          <div className="flex gap-3 justify-end">
            <Btn variant="secondary" onClick={() => { setAddOpen(false); setFormError(''); }}>Cancel</Btn>
            <Btn onClick={handleAdd} disabled={saving}>{saving ? 'Adding…' : 'Add Staff'}</Btn>
          </div>
        }
      >
        <div className="space-y-4">
          {formError && <p className="text-red-400 text-sm p-3 rounded-xl bg-red-500/10">{formError}</p>}
          <FormInput label="Full Name" value={form.fullName} onChange={e => setForm(f => ({ ...f, fullName: e.target.value }))} placeholder="Abebe Kebede" />
          <FormInput label="Phone" value={form.phone} onChange={e => setForm(f => ({ ...f, phone: e.target.value }))} placeholder="0911234567" />
          <FormSelect label="Role" value={form.role} onChange={e => setForm(f => ({ ...f, role: e.target.value }))}>
            <option value="CASHIER">Cashier</option>
            <option value="WAITER">Waiter</option>
            <option value="MANAGER">Manager</option>
          </FormSelect>
          <FormInput label="Password" type="password" value={form.password} onChange={e => setForm(f => ({ ...f, password: e.target.value }))} placeholder="Min 6 characters" />
        </div>
      </Modal>

      <ConfirmDialog
        open={!!deleteTarget}
        onClose={() => setDeleteTarget(null)}
        onConfirm={handleDelete}
        loading={saving}
        title="Remove Staff Member"
        message={`Remove ${deleteTarget?.user?.fullName ?? 'this employee'}? They will lose access immediately.`}
        confirmLabel="Remove"
        danger
      />
    </div>
  );
}
