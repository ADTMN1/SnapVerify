import type { ReactNode } from 'react';

interface PageHeaderProps {
  title: string;
  subtitle?: string;
  actions?: ReactNode;
}

export function PageHeader({ title, subtitle, actions }: PageHeaderProps) {
  return (
    <div className="flex items-start justify-between gap-4 mb-6">
      <div>
        <h1 className="text-white text-xl font-bold tracking-tight">{title}</h1>
        {subtitle && <p className="text-slate-500 text-sm mt-0.5">{subtitle}</p>}
      </div>
      {actions && <div className="flex items-center gap-2 flex-shrink-0">{actions}</div>}
    </div>
  );
}

export function Btn({
  children, onClick, variant = 'primary', size = 'md', disabled = false, type = 'button', className = '',
}: {
  children: ReactNode; onClick?: () => void; variant?: 'primary' | 'secondary' | 'danger' | 'ghost';
  size?: 'sm' | 'md'; disabled?: boolean; type?: 'button' | 'submit'; className?: string;
}) {
  const base = 'inline-flex items-center gap-2 font-semibold rounded-xl transition-all disabled:opacity-50 disabled:cursor-not-allowed';
  const sizes = { sm: 'px-3 py-1.5 text-xs', md: 'px-4 py-2.5 text-sm' };
  const variants = {
    primary:   'text-slate-900 hover:opacity-90',
    secondary: 'bg-slate-800 text-white hover:bg-slate-700',
    danger:    'bg-red-500/10 text-red-400 border border-red-500/30 hover:bg-red-500/20',
    ghost:     'text-slate-400 hover:text-white hover:bg-slate-800',
  };
  return (
    <button
      type={type}
      onClick={onClick}
      disabled={disabled}
      className={`${base} ${sizes[size]} ${variants[variant]} ${className}`}
      style={variant === 'primary' ? { background: '#B8FF3B' } : {}}
    >
      {children}
    </button>
  );
}
