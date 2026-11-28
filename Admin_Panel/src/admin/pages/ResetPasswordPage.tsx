import { useState, type FormEvent } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { ShieldCheck, Eye, EyeOff, Lock, Loader2, CheckCircle, AlertCircle } from 'lucide-react';
import { useAuth } from '../hooks/useAuth';
import { API_BASE_URL } from '../constants';

export default function ResetPasswordPage() {
  const { login } = useAuth();
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  const emailFromUrl = searchParams.get('email') || '';

  const [email, setEmail] = useState(emailFromUrl);
  const [otpCode, setOtpCode] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [showPass, setShowPass] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState(false);

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setError('');

    if (newPassword !== confirmPassword) {
      setError('Passwords do not match');
      return;
    }

    if (newPassword.length < 8) {
      setError('Password must be at least 8 characters');
      return;
    }

    if (!otpCode || otpCode.length !== 6) {
      setError('Please enter the 6-digit verification code');
      return;
    }

    setLoading(true);
    try {
      const res = await fetch(`${API_BASE_URL}/api/admin/auth/reset-password`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, otpCode, newPassword }),
      });
      let data;
      try {
        data = await res.json();
      } catch {
        throw new Error('Invalid response from server');
      }
      if (!res.ok) {
        throw new Error(data?.message || 'Failed to reset password');
      }
      setSuccess(true);
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : 'Failed to reset password. Please try again.';
      setError(msg);
    } finally {
      setLoading(false);
    }
  }

  function handleBackToLogin() {
    navigate('/login');
  }

  return (
    <div className="min-h-screen bg-app flex items-center justify-center p-4">
      <div className="absolute inset-0 overflow-hidden pointer-events-none">
        <div className="absolute top-1/4 left-1/2 -translate-x-1/2 w-96 h-96 rounded-full opacity-10"
          style={{ background: 'radial-gradient(circle,#B8FF3B,transparent)' }} />
      </div>

      <div className="relative w-full max-w-sm">
        <div className="flex flex-col items-center mb-8">
          <div className="w-14 h-14 rounded-2xl flex items-center justify-center mb-4"
            style={{ background: 'linear-gradient(135deg,#B8FF3B,#a3e635)' }}>
            <ShieldCheck size={28} className="text-slate-900" />
          </div>
          <h1 className="text-white text-2xl font-black tracking-tight">
            Snap<span className="text-[#B8FF3B]">Verify</span></h1>
          <p className="text-slate-500 text-sm mt-1">Admin Dashboard</p>
        </div>

        <div className="bg-card rounded-2xl border border-slate-800 p-6 shadow-2xl">
          {!success ? (
            <>
              <h2 className="text-white font-bold text-lg mb-1">Reset Password</h2>
              <p className="text-slate-500 text-sm mb-6">Enter the 6-digit code sent to your email and set a new password.</p>

              {error && (
                <div className="mb-4 p-3 rounded-xl border border-red-500/30 text-red-400 text-sm flex items-center gap-2"
                  style={{ background: 'rgba(239,68,68,0.08)' }}>
                  <AlertCircle size={16} />
                  {error}
                </div>
              )}

              <form onSubmit={handleSubmit} className="space-y-4">
                {/* Email (hidden if from URL, editable otherwise) */}
                {!emailFromUrl && (
                  <div className="flex flex-col gap-1.5">
                    <label className="text-slate-300 text-sm font-medium">Email</label>
                    <div className="relative">
                      <input
                        type="email"
                        value={email}
                        onChange={e => setEmail(e.target.value)}
                        placeholder="admin@email.com"
                        required
                        className="w-full bg-slate-900 border border-slate-700 rounded-xl pl-4 pr-4 py-3 text-sm text-white placeholder-slate-500 focus:outline-none focus:border-slate-500 transition-colors"
                      />
                    </div>
                  </div>
                )}
                {emailFromUrl && (
                  <input type="hidden" value={email} onChange={e => setEmail(e.target.value)} />
                )}

                {/* OTP Code */}
                <div className="flex flex-col gap-1.5">
                  <label className="text-slate-300 text-sm font-medium">Verification Code</label>
                  <div className="relative">
                    <Lock size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-500 pointer-events-none" />
                    <input
                      type="text"
                      value={otpCode}
                      onChange={e => setOtpCode(e.target.value.replace(/\D/g, '').slice(0, 6))}
                      placeholder="123456"
                      required
                      maxLength={6}
                      className="w-full bg-slate-900 border border-slate-700 rounded-xl pl-9 pr-4 py-3 text-sm text-white placeholder-slate-500 focus:outline-none focus:border-slate-500 transition-colors text-center tracking-widest font-mono"
                    />
                  </div>
                  <p className="text-slate-600 text-xs">Enter the 6-digit code from your email</p>
                </div>

                {/* New Password */}
                <div className="flex flex-col gap-1.5">
                  <label className="text-slate-300 text-sm font-medium">New Password</label>
                  <div className="relative">
                    <Lock size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-500 pointer-events-none" />
                    <input
                      type={showPass ? 'text' : 'password'}
                      value={newPassword}
                      onChange={e => setNewPassword(e.target.value)}
                      placeholder="New password (min 8 chars)"
                      required
                      className="w-full bg-slate-900 border border-slate-700 rounded-xl pl-9 pr-10 py-3 text-sm text-white placeholder-slate-500 focus:outline-none focus:border-slate-500 transition-colors"
                    />
                    <button type="button" onClick={() => setShowPass(s => !s)}
                      className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-500 hover:text-slate-300 transition-colors">
                      {showPass ? <EyeOff size={15} /> : <Eye size={15} />}
                    </button>
                  </div>
                </div>

                {/* Confirm Password */}
                <div className="flex flex-col gap-1.5">
                  <label className="text-slate-300 text-sm font-medium">Confirm Password</label>
                  <div className="relative">
                    <Lock size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-500 pointer-events-none" />
                    <input
                      type={showPass ? 'text' : 'password'}
                      value={confirmPassword}
                      onChange={e => setConfirmPassword(e.target.value)}
                      placeholder="Confirm new password"
                      required
                      className="w-full bg-slate-900 border border-slate-700 rounded-xl pl-9 pr-10 py-3 text-sm text-white placeholder-slate-500 focus:outline-none focus:border-slate-500 transition-colors"
                    />
                    <button type="button" onClick={() => setShowPass(s => !s)}
                      className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-500 hover:text-slate-300 transition-colors">
                      {showPass ? <EyeOff size={15} /> : <Eye size={15} />}
                    </button>
                  </div>
                </div>

                <button
                  type="submit"
                  disabled={loading}
                  className="w-full py-3 rounded-xl text-sm font-bold transition-all disabled:opacity-50 disabled:cursor-not-allowed hover:opacity-90"
                  style={{ background: '#B8FF3B', color: '#0f172a' }}
                >
                  {loading ? (
                    <span className="flex items-center justify-center gap-2">
                      <Loader2 size={16} className="animate-spin" />
                      Resetting…
                    </span>
                  ) : 'Reset Password'}
                </button>
              </form>
            </>
          ) : (
            <div className="text-center py-4">
              <div className="w-16 h-16 rounded-full flex items-center justify-center mx-auto mb-4"
                style={{ background: 'rgba(184,255,59,0.15)' }}>
                <CheckCircle size={32} className="text-[#B8FF3B]" />
              </div>
              <h3 className="text-white font-bold text-lg mb-2">Password Reset!</h3>
              <p className="text-slate-500 text-sm mb-6">Your password has been successfully reset.</p>
              <button
                onClick={handleBackToLogin}
                className="w-full py-3 rounded-xl text-sm font-bold transition-all hover:opacity-90"
                style={{ background: '#B8FF3B', color: '#0f172a' }}
              >
                Sign In Now
              </button>
            </div>
          )}

          <p className="text-slate-600 text-xs text-center mt-4">SnapVerify Admin Panel · Secure Access Only</p>
        </div>
      </div>
    </div>
  );
}