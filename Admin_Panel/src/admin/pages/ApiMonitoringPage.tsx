import { useState, useEffect, useCallback } from 'react';
import { CheckCircle, AlertTriangle, Clock, Zap, RefreshCw } from 'lucide-react';
import { LineChart, Line, XAxis, YAxis, Tooltip, ResponsiveContainer, CartesianGrid } from 'recharts';
import { PageHeader } from '../components/layout/PageHeader';
import { ChartCard } from '../components/ui/Cards';
import { formatRelative } from '../utils';
import { adminDashboardApi } from '../services/api';

const TT = { backgroundColor: '#0D1926', border: '1px solid #334155', borderRadius: 12, color: '#f1f5f9', fontSize: 12 };

const PROBED_ENDPOINT = 'GET /api/admin/dashboard';

export default function ApiMonitoringPage() {
  const [latencyData, setLatencyData] = useState<{ time: string; ms: number }[]>([]);
  const [successfulProbes, setSuccessfulProbes] = useState(0);
  const [failedProbes, setFailedProbes] = useState(0);
  const [loading, setLoading] = useState(false);
  const [lastChecked, setLastChecked] = useState<Date | null>(null);

  const probe = useCallback(async () => {
    setLoading(true);
    const start = Date.now();
    try {
      await adminDashboardApi.stats();
      const ms = Date.now() - start;
      const now = new Date();
      setLatencyData(prev => [...prev.slice(-19), { time: now.toLocaleTimeString(), ms }]);
      setSuccessfulProbes(c => c + 1);
      setLastChecked(now);
    } catch {
      setFailedProbes(c => c + 1);
      setLastChecked(new Date());
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    probe();
    const t = setInterval(probe, 15000);
    return () => clearInterval(t);
  }, [probe]);

  const avgLatency = latencyData.length ? Math.round(latencyData.reduce((a, d) => a + d.ms, 0) / latencyData.length) : 0;
  const maxLatency = latencyData.length ? Math.max(...latencyData.map(d => d.ms)) : 0;
  const totalProbes = successfulProbes + failedProbes;
  const successRate = totalProbes ? Math.round((successfulProbes / totalProbes) * 100) : null;
  const health = failedProbes > 0 ? 'Degraded' : successfulProbes > 0 ? 'Healthy' : 'Checking…';
  const healthColor = failedProbes > 0 ? '#ef4444' : successfulProbes > 0 ? '#B8FF3B' : '#f59e0b';

  return (
    <div className="p-4 md:p-6 space-y-6">
      <PageHeader title="API Monitoring" subtitle="Health, latency, and usage metrics"
        actions={
          <button onClick={probe} disabled={loading} className="p-2 rounded-xl text-slate-400 hover:text-white hover:bg-slate-800 transition-colors disabled:opacity-50">
            <RefreshCw size={16} className={loading ? 'animate-spin' : ''} />
          </button>
        }
      />

      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        {[
          { label: 'Overall Health', value: health, color: healthColor, icon: <CheckCircle size={18} /> },
          { label: 'Avg Latency', value: avgLatency ? `${avgLatency}ms` : '—', color: '#0ea5e9', icon: <Clock size={18} /> },
          { label: 'Successful Probes', value: successfulProbes, color: '#a78bfa', icon: <Zap size={18} /> },
          { label: 'Failed Probes', value: failedProbes, color: failedProbes ? '#ef4444' : '#f59e0b', icon: <AlertTriangle size={18} /> },
        ].map(s => (
          <div key={s.label} className="bg-card rounded-2xl border border-slate-800 p-4 flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl flex items-center justify-center flex-shrink-0" style={{ background: `${s.color}20`, color: s.color }}>{s.icon}</div>
            <div>
              <p className="text-white text-lg font-bold">{s.value}</p>
              <p className="text-slate-500 text-xs">{s.label}</p>
            </div>
          </div>
        ))}
      </div>

      <ChartCard title="API Latency (live probe)" subtitle={lastChecked ? `Last checked ${formatRelative(lastChecked.toISOString())}${maxLatency ? ` · max ${maxLatency}ms` : ''}` : 'Probing…'}>
        <ResponsiveContainer width="100%" height={220}>
          <LineChart data={latencyData}>
            <CartesianGrid strokeDasharray="3 3" stroke="#1e293b" />
            <XAxis dataKey="time" tick={{ fill: '#64748b', fontSize: 10 }} axisLine={false} tickLine={false} />
            <YAxis tick={{ fill: '#64748b', fontSize: 11 }} axisLine={false} tickLine={false} unit="ms" />
            <Tooltip contentStyle={TT} formatter={(v) => [`${v}ms`, 'Latency']} />
            <Line type="monotone" dataKey="ms" stroke="#B8FF3B" strokeWidth={2} dot={{ fill: '#B8FF3B', r: 3 }} name="Latency" />
          </LineChart>
        </ResponsiveContainer>
      </ChartCard>

      <div className="bg-card rounded-2xl border border-slate-800 overflow-hidden">
        <div className="px-5 py-4 border-b border-slate-800">
          <h3 className="text-white font-semibold text-sm">Endpoint Health</h3>
          <p className="text-slate-600 text-xs mt-0.5">Only the endpoint backing this probe is measured; per-endpoint metrics require a monitoring backend.</p>
        </div>
        <div className="overflow-x-auto scrollbar-thin">
          <table className="w-full text-sm">
            <thead className="bg-slate-900/80">
              <tr>{['Endpoint', 'Status', 'Session Success Rate'].map(h => (
                <th key={h} className="px-4 py-3 text-left text-xs font-semibold text-slate-400 uppercase tracking-wider whitespace-nowrap">{h}</th>
              ))}</tr>
            </thead>
            <tbody className="divide-y divide-slate-800">
              <tr className="hover:bg-slate-800/30 transition-colors">
                <td className="px-4 py-3 font-mono text-slate-300 text-xs">{PROBED_ENDPOINT}</td>
                <td className="px-4 py-3">
                  <span className="inline-flex items-center gap-1.5 text-xs font-semibold" style={{ color: healthColor }}>
                    {failedProbes > 0 ? <AlertTriangle size={13} /> : <CheckCircle size={13} />}{health.toLowerCase()}
                  </span>
                </td>
                <td className="px-4 py-3 text-slate-300 text-xs">{successRate === null ? 'N/A' : `${successRate}%`}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <div className="bg-card rounded-2xl border border-slate-800 p-6 text-center">
        <p className="text-slate-500 text-sm">Webhook logs require a dedicated webhook event store. Add a <code className="text-slate-300 bg-slate-800 px-1.5 py-0.5 rounded text-xs">WebhookLog</code> model and endpoint to the backend to enable this section.</p>
      </div>
    </div>
  );
}
