import { useState } from 'react';
import { Settings, Shield, Bell, Database, Key } from 'lucide-react';
import { PageHeader, Btn } from '../components/layout/PageHeader';
import { FormInput, FormSelect } from '../components/ui/Overlays';
import { adminAuthApi } from '../services/api';

type Tab = 'general' | 'security' | 'notifications' | 'session' | 'backup';

const TABS: { id: Tab; label: string; icon: React.ElementType }[] = [
  { id: 'general',       label: 'General',       icon: Settings },
  { id: 'security',      label: 'Security',      icon: Shield },
  { id: 'notifications', label: 'Notifications', icon: Bell },
  { id: 'session',       label: 'Session',       icon: Key },
  { id: 'backup',        label: 'Backup',        icon: Database },
];

function Toggle({ checked, onChange }: { checked: boolean; onChange: (v: boolean) => void }) {
  return (
    <button onClick={() => onChange(!checked)} className="relative w-11 h-6 rounded-full transition-colors flex-shrink-0"
      style={{ background: checked ? '#B8FF3B' : '#334155' }}>
      <span className="absolute top-0.5 left-0.5 w-5 h-5 rounded-full bg-white shadow transition-transform"
        style={{ transform: checked ? 'translateX(20px)' : 'translateX(0)' }} />
    </button>
  );
}

function Row({ label, desc, children }: { label: string; desc?: string; children: React.ReactNode }) {
  return (
    <div className="flex items-center justify-between gap-4 py-4 border-b border-slate-800 last:border-0">
      <div className="flex-1 min-w-0">
        <p className="text-white text-sm font-medium">{label}</p>
        {desc && <p className="text-slate-500 text-xs mt-0.5">{desc}</p>}
      </div>
      <div className="flex-shrink-0">{children}</div>
    </div>
  );
}

export default function SettingsPage() {
  const [tab, setTab] = useState<Tab>('general');
  const [settings, setSettings] = useState({ timezone: 'Africa/Addis_Ababa', currency: 'ETB', language: 'en', twoFactor: false, emailNotifs: true, smsNotifs: true, fraudAlerts: true, sessionTimeout: '30', autoLogout: true, backupEnabled: false });
  const [pwForm, setPwForm] = useState({ current: '', next: '', confirm: '' });
  const [pwError, setPwError] = useState('');
  const [pwSuccess, setPwSuccess] = useState('');
  const [pwLoading, setPwLoading] = useState(false);

  function set(k: keyof typeof settings, v: string | boolean) { setSettings(s => ({ ...s, [k]: v })); }

  async function handleChangePassword() {
    setPwError(''); setPwSuccess('');
    if (!pwForm.current || !pwForm.next) { setPwError('All fields required'); return; }
    if (pwForm.next !== pwForm.confirm) { setPwError('Passwords do not match'); return; }
    if (pwForm.next.length < 6) { setPwError('Minimum 6 characters'); return; }
    setPwLoading(true);
    try {
      await adminAuthApi.changePassword(pwForm.current, pwForm.next);
      setPwSuccess('Password changed successfully');
      setPwForm({ current: '', next: '', confirm: '' });
    } catch (err: any) {
      setPwError(err?.response?.data?.message ?? 'Failed to change password');
    } finally { setPwLoading(false); }
  }

  return (
    <div className="p-4 md:p-6 space-y-6">
      <PageHeader title="Settings" subtitle="Configure your admin panel" />
      <div className="flex flex-col lg:flex-row gap-6">
        <div className="lg:w-48 flex-shrink-0">
          <div className="bg-card rounded-2xl border border-slate-800 p-2 flex lg:flex-col gap-1 overflow-x-auto scrollbar-thin">
            {TABS.map(t => {
              const Icon = t.icon;
              return (
                <button key={t.id} onClick={() => setTab(t.id)}
                  className="flex items-center gap-2.5 px-3 py-2.5 rounded-xl text-sm font-medium transition-all whitespace-nowrap flex-shrink-0"
                  style={tab === t.id ? { background: '#B8FF3B', color: '#0f172a' } : { color: '#94a3b8' }}>
                  <Icon size={15} />{t.label}
                </button>
              );
            })}
          </div>
        </div>

        <div className="flex-1 bg-card rounded-2xl border border-slate-800 p-6">
          {tab === 'general' && (
            <div className="space-y-6">
              <h3 className="text-white font-semibold text-sm">General Settings</h3>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <FormSelect label="Timezone" value={settings.timezone} onChange={e => set('timezone', e.target.value)}>
                  <option value="Africa/Addis_Ababa">Africa/Addis Ababa (EAT)</option>
                  <option value="UTC">UTC</option>
                </FormSelect>
                <FormSelect label="Currency" value={settings.currency} onChange={e => set('currency', e.target.value)}>
                  <option value="ETB">ETB — Ethiopian Birr</option>
                  <option value="USD">USD</option>
                </FormSelect>
                <FormSelect label="Language" value={settings.language} onChange={e => set('language', e.target.value)}>
                  <option value="en">English</option>
                  <option value="am">Amharic</option>
                </FormSelect>
              </div>
              <p className="text-slate-600 text-xs">General preferences are stored locally and don't require a backend endpoint.</p>
            </div>
          )}

          {tab === 'security' && (
            <div>
              <h3 className="text-white font-semibold text-sm mb-4">Security</h3>
              <Row label="Two-Factor Authentication" desc="Require OTP on every login (coming soon)">
                <Toggle checked={settings.twoFactor} onChange={v => set('twoFactor', v)} />
              </Row>
              <div className="py-4 border-b border-slate-800">
                <p className="text-white text-sm font-medium mb-4">Change Password</p>
                {pwError && <p className="text-red-400 text-xs mb-3 p-2 rounded-lg bg-red-500/10">{pwError}</p>}
                {pwSuccess && <p className="text-[#B8FF3B] text-xs mb-3 p-2 rounded-lg bg-[#B8FF3B]/10">{pwSuccess}</p>}
                <div className="space-y-3">
                  <FormInput label="Current Password" type="password" value={pwForm.current} onChange={e => setPwForm(f => ({ ...f, current: e.target.value }))} placeholder="Current password" />
                  <FormInput label="New Password" type="password" value={pwForm.next} onChange={e => setPwForm(f => ({ ...f, next: e.target.value }))} placeholder="Min 6 characters" />
                  <FormInput label="Confirm Password" type="password" value={pwForm.confirm} onChange={e => setPwForm(f => ({ ...f, confirm: e.target.value }))} placeholder="Repeat new password" />
                  <Btn onClick={handleChangePassword} disabled={pwLoading}>{pwLoading ? 'Saving…' : 'Change Password'}</Btn>
                </div>
              </div>
              <Row label="Logout All Devices" desc="Terminate all active sessions">
                <Btn variant="danger" size="sm" onClick={async () => { try { await adminAuthApi.logoutAll(); } catch { /* ignore */ } }}>Logout All</Btn>
              </Row>
            </div>
          )}

          {tab === 'notifications' && (
            <div>
              <h3 className="text-white font-semibold text-sm mb-4">Notification Preferences</h3>
              <Row label="Email Notifications" desc="Receive alerts via email"><Toggle checked={settings.emailNotifs} onChange={v => set('emailNotifs', v)} /></Row>
              <Row label="SMS Notifications" desc="Receive alerts via SMS"><Toggle checked={settings.smsNotifs} onChange={v => set('smsNotifs', v)} /></Row>
              <Row label="Fraud Alerts" desc="Immediate alerts for high-risk transactions"><Toggle checked={settings.fraudAlerts} onChange={v => set('fraudAlerts', v)} /></Row>
              <p className="text-slate-600 text-xs mt-4">Notification preferences require a backend settings endpoint to persist.</p>
            </div>
          )}

          {tab === 'session' && (
            <div>
              <h3 className="text-white font-semibold text-sm mb-4">Session Management</h3>
              <Row label="Auto Logout" desc="Logout after inactivity"><Toggle checked={settings.autoLogout} onChange={v => set('autoLogout', v)} /></Row>
              <div className="py-4">
                <p className="text-white text-sm font-medium mb-3">Session Timeout</p>
                <FormSelect label="" value={settings.sessionTimeout} onChange={e => set('sessionTimeout', e.target.value)}>
                  <option value="15">15 minutes</option>
                  <option value="30">30 minutes</option>
                  <option value="60">1 hour</option>
                  <option value="120">2 hours</option>
                </FormSelect>
              </div>
            </div>
          )}

          {tab === 'backup' && (
            <div>
              <h3 className="text-white font-semibold text-sm mb-4">Backup & Data</h3>
              <Row label="Automatic Backups" desc="Daily backup of transaction data"><Toggle checked={settings.backupEnabled} onChange={v => set('backupEnabled', v)} /></Row>
              <Row label="Export All Data" desc="Download full transaction history">
                <Btn variant="secondary" size="sm">Export</Btn>
              </Row>
              <p className="text-slate-600 text-xs mt-4">Backup and export functionality requires a dedicated backend endpoint.</p>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
