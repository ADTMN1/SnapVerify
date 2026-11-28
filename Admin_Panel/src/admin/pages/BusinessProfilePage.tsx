import { useState, useEffect, useCallback } from 'react';
import { Building, Phone, Mail, MapPin, Globe, Edit, RefreshCw } from 'lucide-react';
import { PageHeader, Btn } from '../components/layout/PageHeader';
import { Modal, FormInput, FormSelect } from '../components/ui/Overlays';
import { PageLoader } from '../components/ui/LoadingSkeleton';
import { formatDate, formatCurrency } from '../utils';
import { adminDataApi } from '../services/api';
import type { Organization, Subscription } from '../types';
import { useAuth } from '../hooks/useAuth';

interface OrgWithMeta extends Organization {
  subscriptions?: Subscription[];
  _count?: { branches: number; userAssignments: number; payments: number; paymentAccounts: number };
}

export default function BusinessProfilePage() {
  const { organization: authOrg } = useAuth();
  const [org, setOrg] = useState<OrgWithMeta | null>(null);
  const [loading, setLoading] = useState(true);
  const [editOpen, setEditOpen] = useState(false);
  const [form, setForm] = useState({ name: '', phone: '', email: '', address: '', city: '', country: '', type: '' });

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const res = await adminDataApi.organization();
      setOrg(res.data);
      const o = res.data;
      setForm({ name: o.name ?? '', phone: o.phone ?? '', email: o.email ?? '', address: o.address ?? '', city: o.city ?? '', country: o.country ?? '', type: o.type ?? '' });
    } catch { /* use auth context fallback */ }
    finally { setLoading(false); }
  }, []);

  useEffect(() => { load(); }, [load]);

  const sub = org?.subscriptions?.[0] ?? null;
  const daysLeft = sub?.endDate ? Math.max(0, Math.ceil((new Date(sub.endDate).getTime() - Date.now()) / 86400000)) : null;
  const displayOrg = org ?? authOrg;

  if (loading) return <PageLoader />;

  return (
    <div className="p-4 md:p-6 space-y-6">
      <PageHeader
        title="Business Profile"
        subtitle="Manage your organization details"
        actions={
          <>
            <Btn variant="secondary" size="sm" onClick={load}><RefreshCw size={14} /></Btn>
            <Btn onClick={() => setEditOpen(true)}><Edit size={14} />Edit Profile</Btn>
          </>
        }
      />

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div className="lg:col-span-2">
          <div className="bg-card rounded-2xl border border-slate-800 p-6">
            <div className="flex items-start gap-5 mb-6">
              <div className="w-20 h-20 rounded-2xl flex items-center justify-center text-2xl font-black flex-shrink-0"
                style={{ background: 'linear-gradient(135deg,#B8FF3B,#a3e635)', color: '#0f172a' }}>
                {(displayOrg?.name ?? 'SV').slice(0, 2).toUpperCase()}
              </div>
              <div>
                <h2 className="text-white text-xl font-bold">{displayOrg?.name ?? '—'}</h2>
                <p className="text-slate-400 text-sm capitalize mt-0.5">{displayOrg?.type ?? '—'}</p>
                <span className="inline-flex items-center gap-1.5 mt-2 px-2.5 py-1 rounded-lg text-xs font-semibold"
                  style={{ background: 'rgba(184,255,59,0.12)', color: '#B8FF3B' }}>
                  <span className="w-1.5 h-1.5 rounded-full bg-[#B8FF3B]" />{displayOrg?.status ?? 'active'}
                </span>
              </div>
            </div>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              {[
                { icon: <Phone size={15} />, label: 'Phone', value: displayOrg?.phone },
                { icon: <Mail size={15} />, label: 'Email', value: displayOrg?.email },
                { icon: <MapPin size={15} />, label: 'Address', value: displayOrg?.address },
                { icon: <Globe size={15} />, label: 'City / Country', value: [displayOrg?.city, displayOrg?.country].filter(Boolean).join(', ') || '—' },
                { icon: <Building size={15} />, label: 'Type', value: displayOrg?.type },
                { icon: <Building size={15} />, label: 'Member Since', value: displayOrg?.createdAt ? formatDate(displayOrg.createdAt) : '—' },
              ].map(item => (
                <div key={item.label} className="flex items-start gap-3 p-3 bg-slate-900 rounded-xl">
                  <span className="text-slate-500 mt-0.5 flex-shrink-0">{item.icon}</span>
                  <div>
                    <p className="text-slate-500 text-xs">{item.label}</p>
                    <p className="text-white text-sm font-medium mt-0.5">{item.value ?? '—'}</p>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>

        <div className="space-y-4">
          {sub && (
            <div className="bg-card rounded-2xl border border-slate-800 p-5">
              <h3 className="text-white font-semibold text-sm mb-4">Subscription</h3>
              <div className="space-y-3">
                {[
                  { label: 'Plan', value: sub.planName.replace(/_/g, ' ') },
                  { label: 'Status', value: sub.status },
                  { label: 'Started', value: formatDate(sub.startDate) },
                  { label: 'Expires', value: sub.endDate ? formatDate(sub.endDate) : 'Never' },
                  { label: 'Max Users', value: sub.maxUsers ?? '—' },
                  { label: 'Max Devices', value: sub.maxDevices ?? '—' },
                ].map(r => (
                  <div key={r.label} className="flex justify-between">
                    <span className="text-slate-500 text-sm">{r.label}</span>
                    <span className="text-white text-sm font-medium capitalize">{String(r.value)}</span>
                  </div>
                ))}
              </div>
              {daysLeft !== null && daysLeft <= 7 && (
                <div className="mt-4 p-3 rounded-xl border border-amber-500/30" style={{ background: 'rgba(245,158,11,0.08)' }}>
                  <p className="text-amber-400 text-xs font-semibold">⚠ {daysLeft} days remaining</p>
                </div>
              )}
            </div>
          )}

          {org?._count && (
            <div className="bg-card rounded-2xl border border-slate-800 p-5">
              <h3 className="text-white font-semibold text-sm mb-4">Quick Stats</h3>
              <div className="space-y-3">
                {[
                  { label: 'Branches', value: org._count.branches, color: '#0ea5e9' },
                  { label: 'Staff', value: org._count.userAssignments, color: '#B8FF3B' },
                  { label: 'Payment Accounts', value: org._count.paymentAccounts, color: '#a78bfa' },
                  { label: 'Total Transactions', value: org._count.payments, color: '#f59e0b' },
                ].map(s => (
                  <div key={s.label} className="flex justify-between items-center">
                    <span className="text-slate-500 text-sm">{s.label}</span>
                    <span className="font-bold text-sm" style={{ color: s.color }}>{s.value}</span>
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>
      </div>

      <Modal open={editOpen} onClose={() => setEditOpen(false)} title="Edit Business Profile" size="lg"
        footer={
          <div className="flex gap-3 justify-end">
            <Btn variant="secondary" onClick={() => setEditOpen(false)}>Cancel</Btn>
            <Btn onClick={() => setEditOpen(false)}>Save Changes</Btn>
            {/* TODO: wire to PATCH /organizations/:id when endpoint is added */}
          </div>
        }
      >
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <p className="text-slate-500 text-xs sm:col-span-2">Organization updates require a dedicated backend endpoint (not yet available). Changes shown here are local only.</p>
          <FormInput label="Business Name" value={form.name} onChange={e => setForm(f => ({ ...f, name: e.target.value }))} />
          <FormSelect label="Business Type" value={form.type} onChange={e => setForm(f => ({ ...f, type: e.target.value }))}>
            <option value="restaurant">Restaurant</option>
            <option value="hotel">Hotel</option>
            <option value="cafe">Café</option>
            <option value="retail">Retail</option>
            <option value="other">Other</option>
          </FormSelect>
          <FormInput label="Phone" value={form.phone} onChange={e => setForm(f => ({ ...f, phone: e.target.value }))} />
          <FormInput label="Email" type="email" value={form.email} onChange={e => setForm(f => ({ ...f, email: e.target.value }))} />
          <FormInput label="Address" value={form.address} onChange={e => setForm(f => ({ ...f, address: e.target.value }))} className="sm:col-span-2" />
          <FormInput label="City" value={form.city} onChange={e => setForm(f => ({ ...f, city: e.target.value }))} />
          <FormInput label="Country" value={form.country} onChange={e => setForm(f => ({ ...f, country: e.target.value }))} />
        </div>
      </Modal>
    </div>
  );
}
