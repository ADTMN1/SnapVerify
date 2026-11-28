import { useState, useEffect, useCallback } from 'react';
import { Bell, CheckCheck, AlertTriangle, CheckCircle, Info, ShieldAlert, X, RefreshCw } from 'lucide-react';
import { PageHeader, Btn } from '../components/layout/PageHeader';
import { formatRelative } from '../utils';
import { adminDashboardApi } from '../services/api';
import type { ActivityLog } from '../types';

type Priority = 'high' | 'medium' | 'low';

interface Notification {
  id: string;
  type: 'fraud' | 'verified' | 'info' | 'alert';
  title: string;
  message: string;
  read: boolean;
  createdAt: string;
  priority: Priority;
}

const PRIORITY_COLORS: Record<Priority, string> = { high: '#ef4444', medium: '#f59e0b', low: '#94a3b8' };

const TYPE_CONFIG: Record<string, { icon: React.ElementType; color: string; bg: string }> = {
  fraud:    { icon: ShieldAlert,   color: '#ef4444', bg: 'rgba(239,68,68,0.12)' },
  verified: { icon: CheckCircle,   color: '#B8FF3B', bg: 'rgba(184,255,59,0.12)' },
  info:     { icon: Info,          color: '#0ea5e9', bg: 'rgba(14,165,233,0.12)' },
  alert:    { icon: AlertTriangle, color: '#f59e0b', bg: 'rgba(245,158,11,0.12)' },
};

function logToNotification(log: ActivityLog): Notification {
  const isFraud = log.action === 'FRAUD_DETECTED';
  const isVerified = log.action === 'PAYMENT_VERIFIED';
  const isLogin = log.action.includes('LOGIN');
  return {
    id: log.id,
    type: isFraud ? 'fraud' : isVerified ? 'verified' : isLogin ? 'alert' : 'info',
    title: log.action.replace(/_/g, ' '),
    message: log.metadata ? JSON.stringify(log.metadata) : `Action by ${log.user?.fullName ?? 'system'}`,
    read: false,
    createdAt: log.createdAt,
    priority: isFraud ? 'high' : isVerified ? 'low' : 'medium',
  };
}

export default function NotificationsPage() {
  const [notifications, setNotifications] = useState<Notification[]>([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState<'all' | 'unread'>('all');

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const res = await adminDashboardApi.activity(50);
      setNotifications((res.data as ActivityLog[]).map(logToNotification));
    } catch { /* ignore */ }
    finally { setLoading(false); }
  }, []);

  useEffect(() => { load(); }, [load]);

  const unread = notifications.filter(n => !n.read).length;
  const displayed = filter === 'unread' ? notifications.filter(n => !n.read) : notifications;

  function markRead(id: string) { setNotifications(ns => ns.map(n => n.id === id ? { ...n, read: true } : n)); }
  function dismiss(id: string) { setNotifications(ns => ns.filter(n => n.id !== id)); }
  function markAllRead() { setNotifications(ns => ns.map(n => ({ ...n, read: true }))); }

  return (
    <div className="p-4 md:p-6 space-y-6">
      <PageHeader
        title="Notifications"
        subtitle={unread > 0 ? `${unread} unread` : 'All caught up'}
        actions={
          <div className="flex gap-2">
            <button onClick={load} className="p-2 rounded-xl text-slate-400 hover:text-white hover:bg-slate-800 transition-colors"><RefreshCw size={16} /></button>
            {unread > 0 && <Btn variant="secondary" size="sm" onClick={markAllRead}><CheckCheck size={14} />Mark all read</Btn>}
          </div>
        }
      />

      <div className="flex gap-2">
        {(['all', 'unread'] as const).map(f => (
          <button key={f} onClick={() => setFilter(f)} className="px-4 py-2 rounded-xl text-sm font-medium transition-all"
            style={filter === f ? { background: '#B8FF3B', color: '#0f172a' } : { color: '#94a3b8' }}>
            {f === 'all' ? `All (${notifications.length})` : `Unread (${unread})`}
          </button>
        ))}
      </div>

      <div className="space-y-2">
        {loading && <p className="text-slate-500 text-sm text-center py-8">Loading…</p>}
        {!loading && displayed.length === 0 && (
          <div className="bg-card rounded-2xl border border-slate-800 py-16 flex flex-col items-center gap-3">
            <div className="w-14 h-14 rounded-2xl bg-slate-800 flex items-center justify-center"><Bell size={24} className="text-slate-600" /></div>
            <p className="text-slate-400 text-sm font-medium">No notifications</p>
          </div>
        )}
        {displayed.map(n => {
          const cfg = TYPE_CONFIG[n.type];
          const Icon = cfg.icon;
          return (
            <div key={n.id} className={`bg-card rounded-2xl border transition-all ${n.read ? 'border-slate-800' : 'border-slate-600'} p-4 flex gap-4 cursor-pointer hover:border-slate-600`}
              onClick={() => markRead(n.id)}>
              <div className="w-10 h-10 rounded-xl flex items-center justify-center flex-shrink-0" style={{ background: cfg.bg }}>
                <Icon size={18} style={{ color: cfg.color }} />
              </div>
              <div className="flex-1 min-w-0">
                <div className="flex items-start justify-between gap-2">
                  <div className="flex items-center gap-2 flex-wrap">
                    <p className={`text-sm font-semibold ${n.read ? 'text-slate-300' : 'text-white'}`}>{n.title}</p>
                    <span className="text-xs px-2 py-0.5 rounded-full font-medium" style={{ background: `${PRIORITY_COLORS[n.priority]}18`, color: PRIORITY_COLORS[n.priority] }}>{n.priority}</span>
                    {!n.read && <span className="w-2 h-2 rounded-full bg-[#B8FF3B] flex-shrink-0" />}
                  </div>
                  <button onClick={e => { e.stopPropagation(); dismiss(n.id); }} className="p-1 rounded-lg text-slate-600 hover:text-slate-400 hover:bg-slate-800 transition-colors flex-shrink-0"><X size={14} /></button>
                </div>
                <p className="text-slate-400 text-xs mt-1 leading-relaxed truncate">{n.message}</p>
                <p className="text-slate-600 text-xs mt-2">{formatRelative(n.createdAt)}</p>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
