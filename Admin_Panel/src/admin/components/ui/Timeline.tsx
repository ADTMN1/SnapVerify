import { CheckCircle, XCircle, LogIn, LogOut, Settings, AlertTriangle, Shield } from 'lucide-react';
import type { ActivityLog, VerificationLog } from '../../types';
import { formatRelative, formatDateTime, getInitials, generateAvatarColor } from '../../utils';

function formatAction(action: string) {
  return action.replace(/_/g, ' ').toLowerCase().replace(/\b\w/g, c => c.toUpperCase());
}

const ACTION_META: Record<string, { icon: React.ElementType; color: string }> = {
  PAYMENT_VERIFIED: { icon: CheckCircle,  color: '#B8FF3B' },
  PAYMENT_REJECTED: { icon: XCircle,      color: '#ef4444' },
  LOGIN:            { icon: LogIn,         color: '#0ea5e9' },
  LOGOUT:           { icon: LogOut,        color: '#94a3b8' },
  SETTINGS_CHANGED: { icon: Settings,      color: '#a78bfa' },
  FRAUD_DETECTED:   { icon: AlertTriangle, color: '#f59e0b' },
};

export function ActivityTimeline({ logs, maxItems = 10 }: { logs: ActivityLog[]; maxItems?: number }) {
  const items = logs.slice(0, maxItems);
  if (!items.length) return <p className="text-slate-500 text-sm py-6 text-center">No activity recorded</p>;
  return (
    <div className="flex flex-col">
      {items.map((log, i) => {
        const meta = ACTION_META[log.action] ?? { icon: Shield, color: '#94a3b8' };
        const Icon = meta.icon;
        return (
          <div key={log.id} className="flex gap-3 relative">
            {i < items.length - 1 && <div className="absolute left-4 top-8 bottom-0 w-px bg-slate-800" />}
            <div className="w-8 h-8 rounded-xl flex items-center justify-center flex-shrink-0 z-10" style={{ background: `${meta.color}20` }}>
              <Icon size={14} style={{ color: meta.color }} />
            </div>
            <div className="flex-1 pb-4 min-w-0">
              <div className="flex items-start justify-between gap-2">
                <div className="min-w-0">
                  <p className="text-white text-sm font-medium">{formatAction(log.action)}</p>
                  {log.user?.fullName && <p className="text-slate-500 text-xs mt-0.5">by {log.user.fullName}</p>}
                  {log.ipAddress && <p className="text-slate-600 text-xs">IP: {log.ipAddress}</p>}
                </div>
                <time className="text-slate-600 text-xs whitespace-nowrap flex-shrink-0" title={formatDateTime(log.createdAt)}>
                  {formatRelative(log.createdAt)}
                </time>
              </div>
            </div>
          </div>
        );
      })}
    </div>
  );
}

export function VerificationTimeline({ logs }: { logs: VerificationLog[] }) {
  if (!logs.length) return <p className="text-slate-500 text-sm py-4 text-center">No verification logs</p>;
  return (
    <div className="flex flex-col">
      {logs.map((log, i) => {
        const ok = log.action === 'VERIFIED';
        const color = ok ? '#B8FF3B' : '#ef4444';
        const Icon = ok ? CheckCircle : XCircle;
        return (
          <div key={log.id} className="flex gap-3 relative">
            {i < logs.length - 1 && <div className="absolute left-4 top-8 bottom-0 w-px bg-slate-800" />}
            <div className="w-8 h-8 rounded-xl flex items-center justify-center flex-shrink-0 z-10" style={{ background: `${color}20` }}>
              <Icon size={14} style={{ color }} />
            </div>
            <div className="flex-1 pb-4">
              <p className="text-white text-sm font-medium">{log.action}</p>
              {log.reason && <p className="text-slate-400 text-xs mt-0.5">{log.reason}</p>}
              {log.matchedProvider && <p className="text-slate-500 text-xs">Provider: {log.matchedProvider}</p>}
              <time className="text-slate-600 text-xs">{formatDateTime(log.createdAt)}</time>
            </div>
          </div>
        );
      })}
    </div>
  );
}

export function EmployeeAvatar({ name, id = '', size = 'md', className = '' }: { name?: string; id?: string; size?: 'sm' | 'md' | 'lg'; className?: string }) {
  const color = generateAvatarColor(id || name || '?');
  const sz = { sm: 'w-7 h-7 text-xs', md: 'w-9 h-9 text-sm', lg: 'w-12 h-12 text-base' }[size];
  return (
    <div className={`${sz} rounded-xl flex items-center justify-center font-bold flex-shrink-0 ${className}`} style={{ background: `${color}25`, color }} title={name}>
      {getInitials(name)}
    </div>
  );
}
