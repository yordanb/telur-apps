import { useState } from 'react';
import { useAuth } from '../lib/auth';
import { isAdmin } from '../lib/crud';
import { fmtNum, toISODate } from '../lib/api';
import { useList } from '../hooks/useList';
import { ErrorBox, Field, FilterBar, PageHead, Pager, inputCls } from '../components/ui';

interface LogRow {
  id: number;
  user_id?: number | null;
  username: string;
  action: string;
  detail?: string | null;
  ip_address?: string | null;
  created_at: string;
}

// Aksi yang dikenal; server boleh mencatat aksi lain (middleware
// menulis "<resource>.create/update/delete") — filter teks tetap bisa.
const KNOWN_ACTIONS = [
  'auth.login',
  'auth.login_failed',
  'auth.logout',
  'auth.register',
  'auth.change_password',
  'users.create',
  'users.update',
  'users.delete',
];

export default function LogAktivitas() {
  const { user } = useAuth();
  const today = new Date();
  const ago = new Date();
  ago.setDate(today.getDate() - 6);
  const [start, setStart] = useState(toISODate(ago));
  const [end, setEnd] = useState(toISODate(today));
  const [action, setAction] = useState('');
  const [username, setUsername] = useState('');

  const { rows, loading, loadingMore, error, hasMore, loadMore } =
    useList<LogRow>('/activity-logs/', {
      start_date: start || undefined,
      end_date: end || undefined,
      action: action || undefined,
      username: username.trim() || undefined,
    });

  if (!isAdmin(user)) {
    return (
      <div className="rounded-2xl bg-white p-8 text-center shadow">
        <p className="text-lg font-semibold">🔒 Khusus admin</p>
        <p className="mt-1 text-sm text-gray-500">Log aktivitas hanya untuk role admin.</p>
      </div>
    );
  }

  return (
    <div className="space-y-4">
      <PageHead title="📋 Log Aktivitas" />
      <FilterBar>
        <Field label="Dari">
          <input type="date" value={start} onChange={(e) => setStart(e.target.value)} className={inputCls} />
        </Field>
        <Field label="Sampai">
          <input type="date" value={end} onChange={(e) => setEnd(e.target.value)} className={inputCls} />
        </Field>
        <Field label="Aksi">
          <select value={action} onChange={(e) => setAction(e.target.value)} className={inputCls}>
            <option value="">Semua</option>
            {KNOWN_ACTIONS.map((a) => <option key={a} value={a}>{a}</option>)}
          </select>
        </Field>
        <Field label="Username">
          <input
            value={username}
            onChange={(e) => setUsername(e.target.value)}
            placeholder="cari…"
            className={inputCls}
          />
        </Field>
      </FilterBar>

      <ErrorBox msg={error} />
      {loading ? (
        <p className="py-6 text-center text-gray-500">Memuat…</p>
      ) : (
        <div className="overflow-x-auto rounded-2xl bg-white shadow">
          <table className="w-full min-w-[640px] text-sm">
            <thead>
              <tr className="bg-gray-50 text-left text-xs text-gray-500">
                <th className="px-4 py-2">Waktu</th>
                <th className="px-4 py-2">User</th>
                <th className="px-4 py-2">Aksi</th>
                <th className="px-4 py-2">Detail</th>
                <th className="px-4 py-2">IP</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((r) => (
                <tr key={r.id} className="border-t">
                  <td className="whitespace-nowrap px-4 py-2 text-gray-500">
                    {new Date(r.created_at).toLocaleString('id-ID', {
                      day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit',
                    })}
                  </td>
                  <td className="px-4 py-2 font-medium">{r.username}</td>
                  <td className="px-4 py-2">
                    <span className={`whitespace-nowrap rounded-full px-2 py-0.5 text-xs font-semibold ${
                      r.action.includes('failed') ? 'bg-red-100 text-red-700' : 'bg-gray-100 text-gray-700'
                    }`}>
                      {r.action}
                    </span>
                  </td>
                  <td className="max-w-xs truncate px-4 py-2 text-gray-600" title={r.detail ?? ''}>
                    {r.detail ?? '—'}
                  </td>
                  <td className="px-4 py-2 text-gray-400">{r.ip_address ?? '—'}</td>
                </tr>
              ))}
            </tbody>
          </table>
          <Pager count={rows.length} hasMore={hasMore} loadingMore={loadingMore} onMore={loadMore} />
          <p className="px-4 pb-2 text-xs text-gray-400">
            Menampilkan {fmtNum(rows.length)} baris · tulis tanpa token valid tidak dicatat.
          </p>
        </div>
      )}
    </div>
  );
}
