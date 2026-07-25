import { useState, type FormEvent } from 'react';
import { useNavigate } from 'react-router-dom';
import { ShieldCheck, Eye, EyeOff, User, Lock } from 'lucide-react';
import { useAuth } from '../hooks/useAuth';

export default function LoginPage() {
  const { login } = useAuth();
  const navigate = useNavigate();
  const [identifier, setIdentifier] = useState('');
  const [password, setPassword] = useState('');
  const [orgId, setOrgId] = useState('');
  const [showPass, setShowPass] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const isEmail = identifier.includes('@');

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setError('');
    setLoading(true);
    try {
      await login(identifier, password, orgId || undefined);
      navigate('/admin');
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : 'Login failed. Check your credentials.';
      setError(msg);
    } finally {
      setLoading(false);
    }
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
            Snap<span className="text-[#B8FF3B]">Verify</span>
          </h1>
          <p className="text-slate-500 text-sm mt-1">Admin Dashboard</p>
        </div>

        <div className="bg-card rounded-2xl border border-slate-800 p-6 shadow-2xl">
          <h2 className="text-white font-bold text-lg mb-1">Welcome back</h2>
          <p className="text-slate-500 text-sm mb-6">Sign in with your phone number or email</p>

          {error && (
            <div className="mb-4 p-3 rounded-xl border border-red-500/30 text-red-400 text-sm"
              style={{ background: 'rgba(239,68,68,0.08)' }}>
              {error}
            </div>
          )}

          <form onSubmit={handleSubmit} className="space-y-4">
            {/* Phone or Email */}
            <div className="flex flex-col gap-1.5">
              <label className="text-slate-300 text-sm font-medium">Phone or Email</label>
              <div className="relative">
                <User size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-500 pointer-events-none" />
                <input
                  type="text"
                  value={identifier}
                  onChange={e => setIdentifier(e.target.value)}
                  placeholder="0912345678 or admin@email.com"
                  required
                  className="w-full bg-slate-900 border border-slate-700 rounded-xl pl-9 pr-4 py-3 text-sm text-white placeholder-slate-500 focus:outline-none focus:border-slate-500 transition-colors"
                />
              </div>
            </div>

            {/* Password */}
            <div className="flex flex-col gap-1.5">
              <label className="text-slate-300 text-sm font-medium">Password</label>
              <div className="relative">
                <Lock size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-500 pointer-events-none" />
                <input
                  type={showPass ? 'text' : 'password'}
                  value={password}
                  onChange={e => setPassword(e.target.value)}
                  placeholder="Your password"
                  required
                  className="w-full bg-slate-900 border border-slate-700 rounded-xl pl-9 pr-10 py-3 text-sm text-white placeholder-slate-500 focus:outline-none focus:border-slate-500 transition-colors"
                />
                <button type="button" onClick={() => setShowPass(s => !s)}
                  className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-500 hover:text-slate-300 transition-colors">
                  {showPass ? <EyeOff size={15} /> : <Eye size={15} />}
                </button>
              </div>
            </div>

            {/* Org ID — only show for phone login with multiple orgs */}
            {!isEmail && (
              <div className="flex flex-col gap-1.5">
                <label className="text-slate-300 text-sm font-medium">
                  Organization ID <span className="text-slate-600 font-normal">(optional)</span>
                </label>
                <input
                  type="text"
                  value={orgId}
                  onChange={e => setOrgId(e.target.value)}
                  placeholder="Leave blank if you have one organization"
                  className="w-full bg-slate-900 border border-slate-700 rounded-xl px-4 py-3 text-sm text-white placeholder-slate-500 focus:outline-none focus:border-slate-500 transition-colors"
                />
              </div>
            )}

            <button
              type="submit"
              disabled={loading}
              className="w-full py-3 rounded-xl text-sm font-bold transition-all disabled:opacity-50 disabled:cursor-not-allowed hover:opacity-90"
              style={{ background: '#B8FF3B', color: '#0f172a' }}
            >
              {loading ? (
                <span className="flex items-center justify-center gap-2">
                  <span className="w-4 h-4 border-2 border-slate-900/30 border-t-slate-900 rounded-full animate-spin" />
                  Signing in…
                </span>
              ) : 'Sign In'}
            </button>
          </form>

          <p className="text-slate-600 text-xs text-center mt-4">SnapVerify Admin Panel · Secure Access Only</p>
        </div>
      </div>
    </div>
  );
}
