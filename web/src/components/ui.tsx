import type { ReactNode } from 'react';

export function Modal({ title, onClose, children }: {
  title: string;
  onClose: () => void;
  children: ReactNode;
}) {
  return (
    <div
      className="fixed inset-0 z-50 flex items-end justify-center bg-black/50 p-0 sm:items-center sm:p-4"
      onClick={onClose}
    >
      <div
        className="max-h-[90vh] w-full max-w-lg overflow-y-auto rounded-t-2xl bg-white p-5 shadow-xl sm:rounded-2xl"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="mb-4 flex items-center justify-between">
          <h2 className="text-lg font-bold text-gray-900">{title}</h2>
          <button onClick={onClose} className="rounded-lg px-2 py-1 text-xl text-gray-400 hover:bg-gray-100">
            ×
          </button>
        </div>
        {children}
      </div>
    </div>
  );
}

export function Field({ label, children }: { label: string; children: ReactNode }) {
  return (
    <label className="block">
      <span className="mb-1 block text-xs font-medium text-gray-600">{label}</span>
      {children}
    </label>
  );
}

export const inputCls =
  'w-full rounded-lg border border-gray-300 px-3 py-2 outline-none focus:border-brand-500 focus:ring-2 focus:ring-brand-200';

export function Btn({ kind = 'ghost', className = '', ...rest }: {
  kind?: 'primary' | 'ghost' | 'danger';
  className?: string;
} & React.ButtonHTMLAttributes<HTMLButtonElement>) {
  const base = {
    primary: 'bg-brand-600 text-white hover:bg-brand-700',
    ghost: 'border border-gray-300 text-gray-700 hover:bg-gray-50',
    danger: 'border border-red-200 text-red-600 hover:bg-red-50',
  }[kind];
  return (
    <button
      className={`rounded-lg px-4 py-2 text-sm font-medium transition disabled:opacity-60 ${base} ${className}`}
      {...rest}
    />
  );
}

export function ErrorBox({ msg, onClose }: { msg: string | null; onClose?: () => void }) {
  if (!msg) return null;
  return (
    <div className="flex items-start justify-between gap-2 rounded-xl bg-red-50 px-4 py-3 text-sm text-red-700">
      <span>{msg}</span>
      {onClose && (
        <button onClick={onClose} className="font-bold">×</button>
      )}
    </div>
  );
}

export function PageHead({ title, action }: { title: string; action?: ReactNode }) {
  return (
    <div className="flex flex-wrap items-center justify-between gap-2">
      <h1 className="text-2xl font-bold text-gray-900">{title}</h1>
      {action}
    </div>
  );
}

export function FilterBar({ children }: { children: ReactNode }) {
  return (
    <div className="flex flex-wrap items-end gap-2 rounded-2xl bg-white p-3 shadow">
      {children}
    </div>
  );
}

export function Pager({ count, hasMore, loadingMore, onMore }: {
  count: number;
  hasMore: boolean;
  loadingMore: boolean;
  onMore: () => void;
}) {
  return (
    <div className="py-3 text-center text-sm text-gray-500">
      {count === 0 ? (
        'Tidak ada data.'
      ) : hasMore ? (
        <button
          onClick={onMore}
          disabled={loadingMore}
          className="rounded-lg border border-gray-300 bg-white px-4 py-2 font-medium text-gray-700 hover:bg-gray-50 disabled:opacity-60"
        >
          {loadingMore ? 'Memuat…' : `Muat lagi (${count} ditampilkan)`}
        </button>
      ) : (
        `— ${count} data —`
      )}
    </div>
  );
}
