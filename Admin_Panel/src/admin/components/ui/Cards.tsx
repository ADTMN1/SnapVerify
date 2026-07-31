import type { ReactNode } from 'react';
import { TrendingUp, TrendingDown } from 'lucide-react';

interface StatCardProps {
  title: string;
  value: string | number;
  icon: ReactNode;
  iconColor?: string;
  change?: string;
  changePositive?: boolean;
  subtitle?: string;
  onClick?: () => void;
}

export function StatCard({ title, value, icon, iconColor = '#B8FF3B', change, changePositive = true, subtitle, onClick }: StatCardProps) {
  return (
    <div
      className={`bg-card rounded-2xl p-5 border border-slate-800 flex flex-col gap-4 ${onClick ? 'cursor-pointer hover:border-slate-600 transition-colors' : ''}`}
      onClick={onClick}
    >
      <div className="flex items-start justify-between">
        <div
          className="w-11 h-11 rounded-xl flex items-center justify-center flex-shrink-0"
          style={{ background: `${iconColor}20` }}
        >
          <span style={{ color: iconColor }}>{icon}</span>
        </div>
        {change !== undefined && (
          <span
            className="inline-flex items-center gap-1 px-2 py-1 rounded-lg text-xs font-semibold"
            style={changePositive
              ? { background: 'rgba(184,255,59,0.12)', color: '#B8FF3B' }
              : { background: 'rgba(239,68,68,0.12)', color: '#ef4444' }
            }
          >
            {changePositive ? <TrendingUp size={12} /> : <TrendingDown size={12} />}
            {change}
          </span>
        )}
      </div>
      <div>
        <p className="text-slate-400 text-sm font-medium mb-1">{title}</p>
        <p className="text-white text-2xl font-bold tracking-tight">{value}</p>
        {subtitle && <p className="text-slate-500 text-xs mt-1">{subtitle}</p>}
      </div>
    </div>
  );
}

interface ChartCardProps {
  title: string;
  subtitle?: string;
  children: ReactNode;
  action?: ReactNode;
  className?: string;
}

export function ChartCard({ title, subtitle, children, action, className = '' }: ChartCardProps) {
  return (
    <div className={`bg-card rounded-2xl p-5 border border-slate-800 ${className}`}>
      <div className="flex items-center justify-between mb-5">
        <div>
          <h3 className="text-white font-semibold text-sm">{title}</h3>
          {subtitle && <p className="text-slate-500 text-xs mt-0.5">{subtitle}</p>}
        </div>
        {action}
      </div>
      {children}
    </div>
  );
}

interface InfoCardProps {
  label: string;
  value: ReactNode;
  icon?: ReactNode;
}

export function InfoCard({ label, value, icon }: InfoCardProps) {
  return (
    <div className="flex items-center gap-3 py-3 border-b border-slate-800 last:border-0">
      {icon && <span className="text-slate-400 flex-shrink-0">{icon}</span>}
      <div className="flex-1 min-w-0">
        <p className="text-slate-500 text-xs">{label}</p>
        <p className="text-white text-sm font-medium truncate">{value}</p>
      </div>
    </div>
  );
}
