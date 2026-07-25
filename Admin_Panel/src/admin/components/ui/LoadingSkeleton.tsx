import type { ReactNode } from 'react';
import { FileSearch } from 'lucide-react';

export function LoadingSkeleton({ rows = 5, cols = 4 }: { rows?: number; cols?: number }) {
  return (
    <div className="rounded-xl border border-slate-800 overflow-hidden">
      <div className="bg-slate-900/80 px-4 py-3 flex gap-4">
        {Array.from({ length: cols }).map((_, i) => (
          <div key={i} className="h-3 bg-slate-700 rounded animate-pulse flex-1" />
        ))}
      </div>
      {Array.from({ length: rows }).map((_, i) => (
        <div key={i} className="px-4 py-3 border-t border-slate-800 flex gap-4">
          {Array.from({ length: cols }).map((_, j) => (
            <div
              key={j}
              className="h-4 bg-slate-800 rounded animate-pulse"
              style={{ flex: 1, animationDelay: `${(i * cols + j) * 50}ms` }}
            />
          ))}
        </div>
      ))}
    </div>
  );
}

export function CardSkeleton({ className = '' }: { className?: string }) {
  return (
    <div className={`bg-card rounded-2xl p-5 border border-slate-800 animate-pulse ${className}`}>
      <div className="flex items-start justify-between mb-4">
        <div className="w-11 h-11 bg-slate-800 rounded-xl" />
        <div className="w-16 h-6 bg-slate-800 rounded-lg" />
      </div>
      <div className="h-3 bg-slate-800 rounded w-24 mb-2" />
      <div className="h-7 bg-slate-800 rounded w-32" />
    </div>
  );
}

export function EmptyState({ message = 'No data found', icon, action }: { message?: string; icon?: ReactNode; action?: ReactNode }) {
  return (
    <div className="flex flex-col items-center justify-center py-16 px-4 text-center">
      <div className="w-14 h-14 rounded-2xl bg-slate-800 flex items-center justify-center mb-4 text-slate-500">
        {icon ?? <FileSearch size={24} />}
      </div>
      <p className="text-slate-400 text-sm font-medium mb-1">{message}</p>
      <p className="text-slate-600 text-xs mb-4">Try adjusting your filters or search terms</p>
      {action}
    </div>
  );
}

export function PageLoader() {
  return (
    <div className="flex items-center justify-center min-h-[400px]">
      <div className="flex flex-col items-center gap-3">
        <div className="w-8 h-8 border-2 border-slate-700 border-t-[#B8FF3B] rounded-full animate-spin" />
        <p className="text-slate-500 text-sm">Loading…</p>
      </div>
    </div>
  );
}
