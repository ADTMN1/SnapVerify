import { useEffect, type ReactNode } from 'react';
import { X, Search, AlertTriangle } from 'lucide-react';

// ── Modal ─────────────────────────────────────────────────────────────────────

interface ModalProps {
  open: boolean;
  onClose: () => void;
  title: string;
  children: ReactNode;
  size?: 'sm' | 'md' | 'lg' | 'xl';
  footer?: ReactNode;
}

const MODAL_SIZES = { sm: 'max-w-sm', md: 'max-w-md', lg: 'max-w-lg', xl: 'max-w-2xl' };

export function Modal({ open, onClose, title, children, size = 'md', footer }: ModalProps) {
  useEffect(() => {
    if (!open) return;
    const handler = (e: KeyboardEvent) => { if (e.key === 'Escape') onClose(); };
    document.addEventListener('keydown', handler);
    return () => document.removeEventListener('keydown', handler);
  }, [open, onClose]);

  if (!open) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4" role="dialog" aria-modal="true">
      <div className="absolute inset-0 bg-black/70 backdrop-blur-sm" onClick={onClose} />
      <div className={`relative w-full ${MODAL_SIZES[size]} bg-card border border-slate-700 rounded-2xl shadow-2xl flex flex-col max-h-[90vh]`}>
        <div className="flex items-center justify-between px-6 py-4 border-b border-slate-800 flex-shrink-0">
          <h2 className="text-white font-semibold text-base">{title}</h2>
          <button onClick={onClose} className="p-1.5 rounded-lg text-slate-400 hover:text-white hover:bg-slate-800 transition-colors" aria-label="Close">
            <X size={18} />
          </button>
        </div>
        <div className="flex-1 overflow-y-auto px-6 py-5 scrollbar-thin">{children}</div>
        {footer && <div className="px-6 py-4 border-t border-slate-800 flex-shrink-0">{footer}</div>}
      </div>
    </div>
  );
}

// ── Drawer ────────────────────────────────────────────────────────────────────

interface DrawerProps {
  open: boolean;
  onClose: () => void;
  title: string;
  children: ReactNode;
  width?: string;
}

export function Drawer({ open, onClose, title, children, width = 'w-full max-w-lg' }: DrawerProps) {
  useEffect(() => {
    if (!open) return;
    const handler = (e: KeyboardEvent) => { if (e.key === 'Escape') onClose(); };
    document.addEventListener('keydown', handler);
    return () => document.removeEventListener('keydown', handler);
  }, [open, onClose]);

  return (
    <div className={`fixed inset-0 z-50 flex justify-end transition-all ${open ? 'pointer-events-auto' : 'pointer-events-none'}`}>
      <div
        className={`absolute inset-0 bg-black/60 backdrop-blur-sm transition-opacity ${open ? 'opacity-100' : 'opacity-0'}`}
        onClick={onClose}
      />
      <div
        className={`relative ${width} h-full bg-card border-l border-slate-700 flex flex-col shadow-2xl transition-transform duration-300 ${open ? 'translate-x-0' : 'translate-x-full'}`}
      >
        <div className="flex items-center justify-between px-6 py-4 border-b border-slate-800 flex-shrink-0">
          <h2 className="text-white font-semibold text-base">{title}</h2>
          <button onClick={onClose} className="p-1.5 rounded-lg text-slate-400 hover:text-white hover:bg-slate-800 transition-colors" aria-label="Close">
            <X size={18} />
          </button>
        </div>
        <div className="flex-1 overflow-y-auto scrollbar-thin">{children}</div>
      </div>
    </div>
  );
}

// ── Confirm Dialog ────────────────────────────────────────────────────────────

interface ConfirmDialogProps {
  open: boolean;
  onClose: () => void;
  onConfirm: () => void;
  title: string;
  message: string;
  confirmLabel?: string;
  danger?: boolean;
  loading?: boolean;
}

export function ConfirmDialog({ open, onClose, onConfirm, title, message, confirmLabel = 'Confirm', danger = false, loading = false }: ConfirmDialogProps) {
  return (
    <Modal open={open} onClose={onClose} title={title} size="sm"
      footer={
        <div className="flex gap-3 justify-end">
          <button onClick={onClose} className="px-4 py-2 rounded-xl text-sm font-medium text-slate-300 hover:text-white hover:bg-slate-800 transition-colors">
            Cancel
          </button>
          <button
            onClick={onConfirm}
            disabled={loading}
            className="px-4 py-2 rounded-xl text-sm font-semibold transition-colors disabled:opacity-50"
            style={danger ? { background: '#ef4444', color: '#fff' } : { background: '#B8FF3B', color: '#0f172a' }}
          >
            {loading ? 'Processing…' : confirmLabel}
          </button>
        </div>
      }
    >
      <div className="flex gap-3">
        {danger && <AlertTriangle size={20} className="text-red-400 flex-shrink-0 mt-0.5" />}
        <p className="text-slate-300 text-sm leading-relaxed">{message}</p>
      </div>
    </Modal>
  );
}

// ── Search Input ──────────────────────────────────────────────────────────────

interface SearchInputProps {
  value: string;
  onChange: (v: string) => void;
  placeholder?: string;
  className?: string;
}

export function SearchInput({ value, onChange, placeholder = 'Search…', className = '' }: SearchInputProps) {
  return (
    <div className={`relative ${className}`}>
      <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-500 pointer-events-none" />
      <input
        type="text"
        value={value}
        onChange={e => onChange(e.target.value)}
        placeholder={placeholder}
        className="w-full bg-slate-900 border border-slate-700 rounded-xl pl-9 pr-4 py-2.5 text-sm text-white placeholder-slate-500 focus:outline-none focus:border-slate-500 transition-colors"
      />
    </div>
  );
}

// ── Select ────────────────────────────────────────────────────────────────────

interface SelectProps {
  value: string;
  onChange: (v: string) => void;
  options: { label: string; value: string }[];
  placeholder?: string;
  className?: string;
}

export function Select({ value, onChange, options, placeholder = 'All', className = '' }: SelectProps) {
  return (
    <select
      value={value}
      onChange={e => onChange(e.target.value)}
      className={`bg-slate-900 border border-slate-700 rounded-xl px-3 py-2.5 text-sm text-white focus:outline-none focus:border-slate-500 transition-colors cursor-pointer ${className}`}
    >
      <option value="">{placeholder}</option>
      {options.map(o => <option key={o.value} value={o.value}>{o.label}</option>)}
    </select>
  );
}

// ── Form Input ────────────────────────────────────────────────────────────────

interface FormInputProps extends React.InputHTMLAttributes<HTMLInputElement> {
  label: string;
  error?: string;
}

export function FormInput({ label, error, className = '', ...props }: FormInputProps) {
  return (
    <div className="flex flex-col gap-1.5">
      <label className="text-slate-300 text-sm font-medium">{label}</label>
      <input
        {...props}
        className={`bg-slate-900 border rounded-xl px-4 py-2.5 text-sm text-white placeholder-slate-500 focus:outline-none transition-colors ${error ? 'border-red-500 focus:border-red-400' : 'border-slate-700 focus:border-slate-500'} ${className}`}
      />
      {error && <p className="text-red-400 text-xs">{error}</p>}
    </div>
  );
}

export function FormSelect({ label, error, children, className = '', ...props }: React.SelectHTMLAttributes<HTMLSelectElement> & { label: string; error?: string }) {
  return (
    <div className="flex flex-col gap-1.5">
      <label className="text-slate-300 text-sm font-medium">{label}</label>
      <select
        {...props}
        className={`bg-slate-900 border rounded-xl px-4 py-2.5 text-sm text-white focus:outline-none transition-colors cursor-pointer ${error ? 'border-red-500' : 'border-slate-700 focus:border-slate-500'} ${className}`}
      >
        {children}
      </select>
      {error && <p className="text-red-400 text-xs">{error}</p>}
    </div>
  );
}
