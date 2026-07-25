import type { PaymentStatus, PaymentProvider, Role } from '../../types';
import {
  PAYMENT_STATUS_COLORS, PAYMENT_STATUS_LABELS,
  PROVIDER_COLORS, PROVIDER_LABELS,
  ROLE_COLORS, ROLE_LABELS,
  RISK_COLORS, getRiskLevel,
} from '../../constants';

interface BadgeProps { className?: string }

export function StatusBadge({ status, className = '' }: { status: PaymentStatus } & BadgeProps) {
  const c = PAYMENT_STATUS_COLORS[status];
  return (
    <span
      className={`inline-flex items-center px-2.5 py-1 rounded-lg text-xs font-semibold border ${className}`}
      style={{ background: c.bg, color: c.text, borderColor: c.border }}
    >
      <span className="w-1.5 h-1.5 rounded-full mr-1.5 inline-block" style={{ background: c.text }} />
      {PAYMENT_STATUS_LABELS[status]}
    </span>
  );
}

export function RiskBadge({ score, className = '' }: { score: number } & BadgeProps) {
  const level = getRiskLevel(score);
  const c = RISK_COLORS[level];
  const labels = { low: 'Low', medium: 'Medium', high: 'High', critical: 'Critical' };
  return (
    <span
      className={`inline-flex items-center gap-1 px-2.5 py-1 rounded-lg text-xs font-semibold ${className}`}
      style={{ background: c.bg, color: c.text }}
    >
      {score} — {labels[level]}
    </span>
  );
}

export function RoleBadge({ role, className = '' }: { role: Role } & BadgeProps) {
  const c = ROLE_COLORS[role];
  return (
    <span
      className={`inline-flex items-center px-2.5 py-1 rounded-lg text-xs font-semibold ${className}`}
      style={{ background: c.bg, color: c.text }}
    >
      {ROLE_LABELS[role]}
    </span>
  );
}

export function ProviderBadge({ provider, className = '' }: { provider: PaymentProvider } & BadgeProps) {
  const color = PROVIDER_COLORS[provider];
  return (
    <span
      className={`inline-flex items-center px-2.5 py-1 rounded-lg text-xs font-semibold ${className}`}
      style={{ background: `${color}20`, color, border: `1px solid ${color}40` }}
    >
      {PROVIDER_LABELS[provider]}
    </span>
  );
}

export function ActiveBadge({ active }: { active: boolean }) {
  return (
    <span
      className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg text-xs font-semibold"
      style={active
        ? { background: 'rgba(184,255,59,0.12)', color: '#B8FF3B' }
        : { background: 'rgba(100,116,139,0.2)', color: '#94a3b8' }
      }
    >
      <span className="w-1.5 h-1.5 rounded-full inline-block" style={{ background: active ? '#B8FF3B' : '#94a3b8' }} />
      {active ? 'Active' : 'Inactive'}
    </span>
  );
}
