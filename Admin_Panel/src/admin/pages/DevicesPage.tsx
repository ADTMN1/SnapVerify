import { useState, useEffect, useCallback } from 'react';
import { Smartphone, Ban, LogOut, CheckCircle, XCircle, RefreshCw } from 'lucide-react';
import { PageHeader } from '../components/layout/PageHeader';
import { EmployeeAvatar } from '../components/ui/Timeline';
import { ConfirmDialog } from '../components/ui/Overlays';
import { LoadingSkeleton } from '../components/ui/LoadingSkeleton';
import { formatDateTime, formatRelative } from '../utils';
import { adminDataApi } from '../services/api';
import type { Device } from '../types';

export default function DevicesPage() {
  const [devices, setDevices] = useState<Device[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [blockTarget, setBlockTarget] = useState<Device | null>(null);
  const [removeTarget, setRemoveTarget] = useState<Device | null>(null);
  const [saving, setSaving] = useState(false);

  const load = useCallback(async () => {
    setLoading(true); setError('');
    try {
      const res = await adminDataApi.devices();
      setDevices(res.data);
    } catch { setError('Failed to load devices'); }
    finally { setLoading(false); }
  }, []);

  useEffect(() => { load(); }, [load]);

  async function handleBlock() {
    if (!blockTarget) return;
    setSaving(true);
    try {
      await adminDataApi.blockDevice(blockTarget.id);
      setBlockTarget(null);
      await load();
    } catch { setBlockTarget(null); }
    finally { setSaving(false); }
  }

  async function handleRemove() {
    if (!removeTarget) return;
    setSaving(true);
    try {
      await adminDataApi.removeDevice(removeTarget.id);
      setRemoveTarget(null);
      await load();
    } catch { setRemoveTarget(null); }
    finally { setSaving(false); }
  }

  const active = devices.filter(d => d.isActive).length;

  return (
    <div className="p-4 md:p-6 space-y-6">
      <PageHeader
        title="Device Management"
        subtitle={loading ? 'Loading…' : `${devices.length} registered devices`}
        actions={<button onClick={load} className="p-2 rounded-xl text-slate-400 hover:text-white hover:bg-slate-800 transition-colors"><RefreshCw size={16} /></button>}
      />

      <div className="grid grid-cols-2 md:grid-cols-3 gap-3">
        {[
          { label: 'Total', value: devices.length, color: '#0ea5e9' },
          { label: 'Active', value: active, color: '#B8FF3B' },
          { label: 'Blocked', value: devices.length - active, color: '#ef4444' },
        ].map(s => (
          <div key={s.label} className="bg-card rounded-2xl border border-slate-800 p-4">
            <p className="text-2xl font-bold" style={{ color: s.color }}>{s.value}</p>
            <p className="text-slate-500 text-xs mt-1">{s.label}</p>
          </div>
        ))}
      </div>

      {error && <p className="text-red-400 text-sm">{error}</p>}

      {loading ? <LoadingSkeleton rows={4} /> : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {devices.map(device => (
            <div key={device.id} className="bg-card rounded-2xl border border-slate-800 p-5 hover:border-slate-600 transition-colors">
              <div className="flex items-start justify-between mb-4">
                <div className="w-10 h-10 rounded-xl flex items-center justify-center"
                  style={{ background: device.isActive ? 'rgba(184,255,59,0.12)' : 'rgba(239,68,68,0.12)' }}>
                  <Smartphone size={18} style={{ color: device.isActive ? '#B8FF3B' : '#ef4444' }} />
                </div>
                <div className="flex items-center gap-1.5">
                  {device.isActive
                    ? <><CheckCircle size={14} className="text-[#B8FF3B]" /><span className="text-[#B8FF3B] text-xs font-semibold">Active</span></>
                    : <><XCircle size={14} className="text-red-400" /><span className="text-red-400 text-xs font-semibold">Blocked</span></>
                  }
                </div>
              </div>
              <p className="text-white font-semibold text-sm mb-1">{device.deviceName ?? 'Unknown Device'}</p>
              <p className="text-slate-500 text-xs font-mono mb-3 truncate">{device.deviceFingerprint}</p>
              {device.userAssignment?.user && (
                <div className="flex items-center gap-2 mb-3">
                  <EmployeeAvatar name={device.userAssignment.user.fullName} id={device.userAssignment.userId} size="sm" />
                  <div>
                    <p className="text-white text-xs font-medium">{device.userAssignment.user.fullName}</p>
                    <p className="text-slate-500 text-xs">{device.userAssignment.role}</p>
                  </div>
                </div>
              )}
              <div className="space-y-1 mb-4">
                <p className="text-slate-600 text-xs">Last login: {formatRelative(device.lastLoginAt)}</p>
                <p className="text-slate-700 text-xs">Registered: {formatDateTime(device.createdAt)}</p>
              </div>
              <div className="flex gap-2">
                {device.isActive && (
                  <button onClick={() => setBlockTarget(device)}
                    className="flex-1 flex items-center justify-center gap-1.5 py-2 rounded-xl text-xs font-semibold text-red-400 border border-red-500/30 hover:bg-red-500/10 transition-colors">
                    <Ban size={12} />Block
                  </button>
                )}
                <button onClick={() => setRemoveTarget(device)}
                  className="flex-1 flex items-center justify-center gap-1.5 py-2 rounded-xl text-xs font-semibold text-slate-400 border border-slate-700 hover:bg-slate-800 transition-colors">
                  <LogOut size={12} />Remove
                </button>
              </div>
            </div>
          ))}
          {devices.length === 0 && <p className="text-slate-500 text-sm col-span-3 py-12 text-center">No devices registered.</p>}
        </div>
      )}

      <ConfirmDialog open={!!blockTarget} onClose={() => setBlockTarget(null)} onConfirm={handleBlock} loading={saving}
        title="Block Device" message={`Block "${blockTarget?.deviceName ?? 'this device'}"? The user will be unable to log in from this device.`} confirmLabel="Block" danger />
      <ConfirmDialog open={!!removeTarget} onClose={() => setRemoveTarget(null)} onConfirm={handleRemove} loading={saving}
        title="Remove Device" message={`Remove "${removeTarget?.deviceName ?? 'this device'}"? This action is permanent.`} confirmLabel="Remove" danger />
    </div>
  );
}
