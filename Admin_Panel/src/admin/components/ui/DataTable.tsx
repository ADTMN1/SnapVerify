import { useState, type ReactNode } from 'react';
import { ChevronUp, ChevronDown, ChevronsUpDown, ChevronLeft, ChevronRight } from 'lucide-react';
import type { TableColumn, SortConfig } from '../../types';
import { LoadingSkeleton } from './LoadingSkeleton';
import { EmptyState } from './LoadingSkeleton';

interface DataTableProps<T> {
  columns: TableColumn<T>[];
  data: T[];
  loading?: boolean;
  keyField?: keyof T;
  onRowClick?: (row: T) => void;
  pageSize?: number;
  emptyMessage?: string;
  emptyIcon?: ReactNode;
  stickyHeader?: boolean;
}

export function DataTable<T extends object>({
  columns, data, loading = false, keyField = 'id' as keyof T,
  onRowClick, pageSize = 10, emptyMessage, emptyIcon, stickyHeader = false,
}: DataTableProps<T>) {
  const [sort, setSort] = useState<SortConfig | null>(null);
  const [page, setPage] = useState(1);

  const sorted = sort
    ? [...data].sort((a, b) => {
        const av = (a as Record<string, unknown>)[sort.key];
        const bv = (b as Record<string, unknown>)[sort.key];
        const cmp = String(av ?? '').localeCompare(String(bv ?? ''), undefined, { numeric: true });
        return sort.direction === 'asc' ? cmp : -cmp;
      })
    : data;

  const totalPages = Math.max(1, Math.ceil(sorted.length / pageSize));
  const paged = sorted.slice((page - 1) * pageSize, page * pageSize);

  function toggleSort(key: string) {
    setSort(prev => {
      if (prev?.key === key) return prev.direction === 'asc' ? { key, direction: 'desc' } : null;
      return { key, direction: 'asc' };
    });
    setPage(1);
  }

  if (loading) return <LoadingSkeleton rows={pageSize} />;
  if (!data.length) return <EmptyState message={emptyMessage} icon={emptyIcon} />;

  return (
    <div className="flex flex-col gap-0">
      <div className="overflow-x-auto scrollbar-thin rounded-xl border border-slate-800">
        <table className="w-full text-sm">
          <thead className={`${stickyHeader ? 'sticky top-0 z-10' : ''} bg-slate-900/80 backdrop-blur-sm`}>
            <tr>
              {columns.map(col => (
                <th
                  key={String(col.key)}
                  className={`px-4 py-3 text-left text-xs font-semibold text-slate-400 uppercase tracking-wider whitespace-nowrap ${col.sortable ? 'cursor-pointer select-none hover:text-white transition-colors' : ''}`}
                  style={col.width ? { width: col.width } : {}}
                  onClick={() => col.sortable && toggleSort(String(col.key))}
                >
                  <span className="inline-flex items-center gap-1">
                    {col.label}
                    {col.sortable && (
                      sort?.key === String(col.key)
                        ? sort.direction === 'asc' ? <ChevronUp size={12} /> : <ChevronDown size={12} />
                        : <ChevronsUpDown size={12} className="opacity-40" />
                    )}
                  </span>
                </th>
              ))}
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-800">
            {paged.map((row, i) => (
              <tr
                key={String((row as Record<string, unknown>)[keyField as string] ?? i)}
                className={`transition-colors ${onRowClick ? 'cursor-pointer hover:bg-slate-800/50' : 'hover:bg-slate-800/20'}`}
                onClick={() => onRowClick?.(row)}
              >
                {columns.map(col => (
                  <td key={String(col.key)} className="px-4 py-3 text-slate-300 whitespace-nowrap">
                    {col.render
                      ? col.render((row as Record<string, unknown>)[col.key as string], row)
                      : String((row as Record<string, unknown>)[col.key as string] ?? '—')}
                  </td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {totalPages > 1 && (
        <div className="flex items-center justify-between px-1 pt-3">
          <p className="text-slate-500 text-xs">
            Showing {(page - 1) * pageSize + 1}–{Math.min(page * pageSize, sorted.length)} of {sorted.length}
          </p>
          <div className="flex items-center gap-1">
            <button
              onClick={() => setPage(p => Math.max(1, p - 1))}
              disabled={page === 1}
              className="p-1.5 rounded-lg text-slate-400 hover:text-white hover:bg-slate-800 disabled:opacity-30 disabled:cursor-not-allowed transition-colors"
            >
              <ChevronLeft size={16} />
            </button>
            {Array.from({ length: Math.min(5, totalPages) }, (_, i) => {
              const pg = totalPages <= 5 ? i + 1 : Math.max(1, Math.min(page - 2, totalPages - 4)) + i;
              return (
                <button
                  key={pg}
                  onClick={() => setPage(pg)}
                  className={`w-8 h-8 rounded-lg text-xs font-medium transition-colors ${pg === page ? 'text-slate-900 font-bold' : 'text-slate-400 hover:text-white hover:bg-slate-800'}`}
                  style={pg === page ? { background: '#B8FF3B' } : {}}
                >
                  {pg}
                </button>
              );
            })}
            <button
              onClick={() => setPage(p => Math.min(totalPages, p + 1))}
              disabled={page === totalPages}
              className="p-1.5 rounded-lg text-slate-400 hover:text-white hover:bg-slate-800 disabled:opacity-30 disabled:cursor-not-allowed transition-colors"
            >
              <ChevronRight size={16} />
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
