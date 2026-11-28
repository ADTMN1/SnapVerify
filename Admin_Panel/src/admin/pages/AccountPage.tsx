import { useState } from 'react';
import { PageHeader, Btn } from '../components/layout/PageHeader';
import { FormInput } from '../components/ui/Overlays';
import { adminAuthApi } from '../services/api';
import { useAuth } from '../hooks/useAuth';

type MsgState = { ok: boolean; text: string } | null;

function Msg({ msg }: { msg: MsgState }) {
  if (!msg) return null;
  return (
    <p className={`text-xs p-2 rounded-lg ${msg.ok ? 'text-[#B8FF3B] bg-[#B8FF3B]/10' : 'text-red-400 bg-red-500/10'}`}>
      {msg.text}
    </p>
  );
}

export default function AccountPage() {
  const { user } = useAuth();

  const [emailForm, setEmailForm] = useState({ newEmail: '', currentPassword: '' });
  const [emailMsg, setEmailMsg] = useState<{ ok: boolean; text: string } | null>(null);
  const [emailLoading, setEmailLoading] = useState(false);

  const [pwForm, setPwForm] = useState({ current: '', next: '', confirm: '' });
  const [pwMsg, setPwMsg] = useState<{ ok: boolean; text: string } | null>(null);
  const [pwLoading, setPwLoading] = useState(false);

  async function handleEmail() {
    setPwMsg(null);
    setEmailMsg(null);
    if (!emailForm.newEmail || !emailForm.currentPassword) {
      setEmailMsg({ ok: false, text: 'New email and current password are required' });
      return;
    }
    setEmailLoading(true);
    try {
      await adminAuthApi.updateProfile(emailForm.currentPassword, emailForm.newEmail);
      setEmailMsg({ ok: true, text: 'Email updated. Please reload to see changes.' });
      setEmailForm({ newEmail: '', currentPassword: '' });
    } catch (err: any) {
      setEmailMsg({ ok: false, text: err?.response?.data?.message ?? 'Failed to update email' });
    } finally { setEmailLoading(false); }
  }

  async function handlePassword() {
    setPwMsg(null);
    if (!pwForm.current || !pwForm.next) {
      setPwMsg({ ok: false, text: 'All fields required' });
      return;
    }
    if (pwForm.next !== pwForm.confirm) {
      setPwMsg({ ok: false, text: 'Passwords do not match' });
      return;
    }
    if (pwForm.next.length < 6) {
      setPwMsg({ ok: false, text: 'Minimum 6 characters' });
      return;
    }
    setPwLoading(true);
    try {
      await adminAuthApi.changePassword(pwForm.current, pwForm.next);
      setPwMsg({ ok: true, text: 'Password changed successfully' });
      setPwForm({ current: '', next: '', confirm: '' });
    } catch (err: any) {
      setPwMsg({ ok: false, text: err?.response?.data?.message ?? 'Failed to change password' });
    } finally { setPwLoading(false); }
  }

  return (
    <div className="p-4 md:p-6 space-y-6 max-w-2xl">
      <PageHeader title="My Account" subtitle="Manage your admin login email and password" />

      <div className="bg-card rounded-2xl border border-slate-800 p-6 space-y-1">
        <p className="text-slate-400 text-xs uppercase tracking-wider">Signed in as</p>
        <p className="text-white font-semibold">{user?.fullName ?? 'Admin'}</p>
        <p className="text-slate-400 text-sm">{user?.email ?? user?.phone ?? '—'}</p>
      </div>

      <div className="bg-card rounded-2xl border border-slate-800 p-6 space-y-4">
        <h3 className="text-white font-semibold text-sm">Change Email</h3>
        <Msg msg={emailMsg} />
        <FormInput label="New Email" type="email" value={emailForm.newEmail} onChange={e => setEmailForm(f => ({ ...f, newEmail: e.target.value }))} placeholder="new@email.com" />
        <FormInput label="Current Password" type="password" value={emailForm.currentPassword} onChange={e => setEmailForm(f => ({ ...f, currentPassword: e.target.value }))} placeholder="Confirm with your current password" />
        <Btn onClick={handleEmail} disabled={emailLoading}>{emailLoading ? 'Saving…' : 'Update Email'}</Btn>
      </div>

      <div className="bg-card rounded-2xl border border-slate-800 p-6 space-y-4">
        <h3 className="text-white font-semibold text-sm">Change Password</h3>
        <Msg msg={pwMsg} />
        <FormInput label="Current Password" type="password" value={pwForm.current} onChange={e => setPwForm(f => ({ ...f, current: e.target.value }))} placeholder="Current password" />
        <FormInput label="New Password" type="password" value={pwForm.next} onChange={e => setPwForm(f => ({ ...f, next: e.target.value }))} placeholder="Min 6 characters" />
        <FormInput label="Confirm Password" type="password" value={pwForm.confirm} onChange={e => setPwForm(f => ({ ...f, confirm: e.target.value }))} placeholder="Repeat new password" />
        <Btn onClick={handlePassword} disabled={pwLoading}>{pwLoading ? 'Saving…' : 'Change Password'}</Btn>
      </div>
    </div>
  );
}