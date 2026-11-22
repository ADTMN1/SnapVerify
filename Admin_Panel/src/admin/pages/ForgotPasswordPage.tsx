import { useState, type FormEvent } from 'react';
import { useNavigate } from 'react-router-dom';
import { ShieldCheck, Mail, Loader2, CheckCircle } from 'lucide-react';
import { useAuth } from '../hooks/useAuth';
import { API_BASE_URL } from '../constants';

export default function ForgotPasswordPage() {
  const { login } = useAuth();
  const navigate = useNavigate();
  const [email, setEmail] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState(false);
  const [message, setMessage] = useState('');

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setError('');
    setLoading(true);
    try {
      const res = await fetch(`${API_BASE_URL}/api/admin/auth/forgot-password`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email }),
      });
      let data;
      try {
        data = await res.json();
      } catch {
        throw new Error('Invalid response from server');
      }
      if (!res.ok) {
        throw new Error(data?.message || 'Failed to send reset code');
      }
      setSuccess(true);
      setMessage(data?.message || 'If an admin account exists for this email, a password reset code has been sent.');
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : 'Failed to send reset code. Please try again.';
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
              <h2 className="text-white font-bold text-lg mb-1">Forgot Password</h2>
              <p className="text-slate-500 text-sm mb-6">Enter your admin email to receive a password reset code.</p>

              {error && (
                <div className="mb-4 p-3 rounded-xl border border-red-500/30 text-red-400 text-sm"
                  style={{ background: 'rgba(239,68,68,0.08)' }}>
                  {error}
                </div>
              )}

              <form onSubmit={handleSubmit} className="space-y-4">
                {/* Email */}
                <div className="flex flex-col gap-1.5">
                  <label className="text-slate-300 text-sm font-medium">Email</label>
                  <div className="relative">
                    <Mail size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-500 pointer-events-none" />
                    <input
                      type="email"
                      value={email}
                      onChange={e => setEmail(e.target.value)}
                      placeholder="admin@email.com"
                      required
                      className="w-full bg-slate-900 border border-slate-700 rounded-xl pl-9 pr-4 py-3 text-sm text-white placeholder-slate-500 focus:outline-none focus:border-slate-500 transition-colors"
                    />
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
                      Sending code…
                    </span>
                  ) : 'Send Reset Code'}
                </button>
              </form>
            </>
          ) : (
            <div className="text-center py-4">
              <div className="w-16 h-16 rounded-full flex items-center justify-center mx-auto mb-4"
                style={{ background: 'rgba(184,255,59,0.15)' }}>
                <CheckCircle size={32} className="text-[#B8FF3B]" />
              </div>
              <h3 className="text-white font-bold text-lg mb-2">Code Sent!</h3>
              <p className="text-slate-500 text-sm mb-6">{message}</p>
              <button
                onClick={handleBackToLogin}
                className="w-full py-3 rounded-xl text-sm font-bold transition-all hover:opacity-90"
                style={{ background: '#B8FF3B', color: '#0f172a' }}
              >
                Back to Login
              </button>
            </div>
          )}

          <p className="text-slate-600 text-xs text-center mt-4">SnapVerify Admin Panel · Secure Access Only</p>
        </div>
      </div>
    </div>
  );
}