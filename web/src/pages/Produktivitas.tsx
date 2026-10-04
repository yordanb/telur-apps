import { useCallback, useEffect, useState } from 'react';
import { fmtNum, toISODate } from '../lib/api';
import { list } from '../lib/crud';
import { ErrorBox, PageHead } from '../components/ui';

interface ProdDetail {
  chicken_id: number;
  eggs: number;
}

interface Production {
  id: number;
  date: string;
  details: ProdDetail[];
}

interface Chicken {
  id: number;
  code: string;
  name?: string | null;
  status: string;
  acquired_date?: string | null;
}

const PERIODS = [
  { days: 7, label: '7 hari' },
  { days: 30, label: '30 hari' },
  { days: 90, label: '90 hari' },
  { days: 0, label: 'Semua' },
];

interface Stat {
  chicken: Chicken;
  total: number;
  days: number;
  avg: number;
  rate: number;
}

// Meniru mobile (productivity_screen.dart):
// laying rate hen-day = total / hari-hadir × 100%,
// hari-hadir = maks(awal periode, tanggal masuk) s.d. hari ini.
export default function Produktivitas() {
  const [days, setDays] = useState(30);
  const [stats, setStats] = useState<Stat[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const now = new Date();
      const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
      const periodStart =
        days === 0 ? new Date(2000, 0, 1) : new Date(today.getTime() - (days - 1) * 86400000);
      const q =
        days === 0 ? '?limit=1000' : `?start_date=${toISODate(periodStart)}&limit=1000`;
      const [prods, chickens] = await Promise.all([
        list<Production>(`/egg-productions/${q}`),
        list<Chicken>('/chickens/?limit=200'),
      ]);

      const eggsByChicken = new Map<number, number>();
      for (const p of prods) {
        for (const d of p.details ?? []) {
          eggsByChicken.set(d.chicken_id, (eggsByChicken.get(d.chicken_id) ?? 0) + d.eggs);
        }
      }

      const rows: Stat[] = chickens.map((c) => {
        const acq = c.acquired_date ? new Date(c.acquired_date) : null;
        const from =
          acq && acq > periodStart
            ? new Date(acq.getFullYear(), acq.getMonth(), acq.getDate())
            : periodStart;
        let n = Math.round((today.getTime() - from.getTime()) / 86400000) + 1;
        if (n < 1) n = 1;
        const total = eggsByChicken.get(c.id) ?? 0;
        return { chicken: c, total, days: n, avg: total / n, rate: (total / n) * 100 };
      });
      setStats(rows);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Gagal memuat');
    } finally {
      setLoading(false);
    }
  }, [days]);

  useEffect(() => {
    void load();
  }, [load]);

  const active = stats.filter((s) => s.chicken.status === 'aktif').sort((a, b) => b.total - a.total);
  const inactive = stats.filter((s) => s.chicken.status !== 'aktif').sort((a, b) => b.total - a.total);
  const top = active.filter((s) => s.total > 0).slice(0, 5);
  const bottom = [...active].reverse().slice(0, 5).reverse();

  function row(s: Stat, rank?: number) {
    const c = s.chicken;
    return (
      <li key={c.id} className="flex items-center justify-between gap-2 py-2">
        <span className="min-w-0">
          {rank != null && <b className="mr-1 text-brand-700">#{rank}</b>}
          <b>{c.code}</b>
          {c.name ? <span className="text-gray-500"> · {c.name}</span> : null}
          {c.status !== 'aktif' && (
            <span className="ml-1 rounded-full bg-gray-200 px-2 py-0.5 text-xs text-gray-600">{c.status}</span>
          )}
        </span>
        <span className="whitespace-nowrap text-sm text-gray-600">
          {fmtNum(s.total)} butir · {s.avg.toFixed(1)}/hari · {s.rate.toFixed(0)}%
        </span>
      </li>
    );
  }

  return (
    <div className="space-y-4">
      <PageHead title="🏆 Produktivitas Ayam" />
      <div className="flex flex-wrap gap-2">
        {PERIODS.map((p) => (
          <button
            key={p.days}
            onClick={() => setDays(p.days)}
            className={`rounded-full px-4 py-1.5 text-sm font-medium ${
              days === p.days ? 'bg-brand-600 text-white' : 'bg-white text-gray-600 shadow'
            }`}
          >
            {p.label}
          </button>
        ))}
      </div>

      <ErrorBox msg={error} />
      {loading ? (
        <p className="py-6 text-center text-gray-500">Memuat…</p>
      ) : stats.length === 0 ? (
        <div className="rounded-2xl bg-white p-8 text-center shadow">
          Belum ada ayam terdaftar. Daftarkan dulu di menu Ayam.
        </div>
      ) : (
        <>
          {top.length > 0 && (
            <div className="rounded-2xl bg-white p-5 shadow">
              <h2 className="font-semibold text-gray-900">⭐ Paling produktif</h2>
              <ul className="mt-1 divide-y text-sm">
                {top.map((s, i) => row(s, i + 1))}
              </ul>
            </div>
          )}
          {bottom.length > 0 && (
            <div className="rounded-2xl bg-white p-5 shadow">
              <h2 className="font-semibold text-gray-900">🐣 Perlu perhatian</h2>
              <ul className="mt-1 divide-y text-sm">{bottom.map((s) => row(s))}</ul>
            </div>
          )}
          <div className="rounded-2xl bg-white p-5 shadow">
            <h2 className="font-semibold text-gray-900">Semua ayam aktif ({active.length})</h2>
            <ul className="mt-1 divide-y text-sm">
              {active.map((s) => row(s))}
              {active.length === 0 && <li className="py-2 text-gray-400">Tidak ada.</li>}
            </ul>
          </div>
          {inactive.length > 0 && (
            <div className="rounded-2xl bg-white p-5 shadow">
              <h2 className="font-semibold text-gray-900">Non-aktif ({inactive.length})</h2>
              <ul className="mt-1 divide-y text-sm">{inactive.map((s) => row(s))}</ul>
            </div>
          )}
          <p className="text-xs text-gray-500">
            Laying rate = total butir ÷ hari-hadir × 100%. Peringkat hanya untuk ayam aktif;
            butuh rincian per ayam di Produksi agar per-ekor terhitung.
          </p>
        </>
      )}
    </div>
  );
}
