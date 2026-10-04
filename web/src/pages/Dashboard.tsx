import { useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { Bar, BarChart, CartesianGrid, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts';
import { useAuth } from '../lib/auth';
import {
  fmtDate, fmtNum, fmtRp, getDailyStats, getMonthlyStats, toISODate,
} from '../lib/api';
import type { DailyStat, MonthlyStat } from '../lib/api';

function sum(rows: DailyStat[], pick: (r: DailyStat) => number): number {
  return rows.reduce((a, r) => a + pick(r), 0);
}

export default function Dashboard() {
  const { user } = useAuth();
  const [daily, setDaily] = useState<DailyStat[]>([]);
  const [monthly, setMonthly] = useState<MonthlyStat[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const end = new Date();
    const start = new Date();
    start.setDate(end.getDate() - 29);
    Promise.all([
      getDailyStats(toISODate(start), toISODate(end)),
      getMonthlyStats(end.getFullYear()),
    ])
      .then(([d, m]) => {
        // API mengembalikan desc berdasarkan tanggal produksi
        setDaily([...d].reverse());
        setMonthly([...m].sort((a, b) => a.month - b.month));
      })
      .catch((e: unknown) => setError(e instanceof Error ? e.message : 'Gagal memuat'))
      .finally(() => setLoading(false));
  }, []);

  const totals = useMemo(
    () => ({
      eggs: sum(daily, (r) => r.total_eggs),
      revenue: sum(daily, (r) => r.sales_revenue),
      feed: sum(daily, (r) => r.feed_cost),
      other: sum(daily, (r) => r.other_cost),
    }),
    [daily],
  );
  const laba = totals.revenue - totals.feed - totals.other;

  const last14 = daily.slice(-14);
  const chartData = last14.map((r) => ({
    t: new Date(r.date).toLocaleDateString('id-ID', { day: 'numeric', month: 'numeric' }),
    full: fmtDate(r.date),
    telur: r.total_eggs,
  }));
  const last7 = daily.slice(-7).reverse();

  if (loading) return <div className="py-10 text-center text-gray-500">Memuat dashboard…</div>;
  if (error) return <div className="rounded-xl bg-red-50 p-4 text-sm text-red-700">{error}</div>;

  const cards = [
    { label: 'Telur 30 hari (butir)', value: fmtNum(totals.eggs), accent: 'text-brand-700' },
    { label: 'Pendapatan 30 hari', value: fmtRp(totals.revenue), accent: 'text-green-700' },
    { label: 'Biaya pakan 30 hari', value: fmtRp(totals.feed), accent: 'text-amber-700' },
    { label: 'Biaya lain 30 hari', value: fmtRp(totals.other), accent: 'text-gray-700' },
  ];

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-end justify-between gap-2">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">
            Halo, {user?.full_name || user?.username} 👋
          </h1>
          <p className="text-sm text-gray-500">
            Ringkasan 30 hari terakhir ·{' '}
            <Link to="/statistik" className="font-medium text-brand-700 hover:underline">
              Lihat statistik lengkap →
            </Link>
          </p>
        </div>
        <span className="rounded-full bg-brand-100 px-3 py-1 text-xs font-semibold text-brand-800">
          {user?.role}
        </span>
      </div>

      <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
        {cards.map((c) => (
          <div key={c.label} className="rounded-2xl bg-white p-4 shadow">
            <p className="text-xs text-gray-500">{c.label}</p>
            <p className={`mt-1 text-xl font-bold ${c.accent}`}>{c.value}</p>
          </div>
        ))}
      </div>

      <div className={`rounded-2xl p-4 shadow ${laba >= 0 ? 'bg-green-50' : 'bg-red-50'}`}>
        <p className="text-xs text-gray-500">Perkiraan laba kotor 30 hari (pendapatan − pakan − lain)</p>
        <p className={`text-2xl font-bold ${laba >= 0 ? 'text-green-700' : 'text-red-700'}`}>
          {fmtRp(laba)}
        </p>
      </div>

      <div className="rounded-2xl bg-white p-5 shadow">
        <h2 className="font-semibold text-gray-900">Produksi 14 hari terakhir</h2>
        {chartData.length === 0 ? (
          <p className="mt-2 text-sm text-gray-500">Belum ada data produksi.</p>
        ) : (
          <div className="mt-4 h-56">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={chartData} margin={{ top: 4, right: 4, bottom: 0, left: -12 }}>
                <CartesianGrid strokeDasharray="3 3" vertical={false} />
                <XAxis dataKey="t" tick={{ fontSize: 11 }} interval="preserveStartEnd" />
                <YAxis tick={{ fontSize: 11 }} allowDecimals={false} />
                <Tooltip
                  labelFormatter={(_, payload) => payload?.[0]?.payload?.full ?? ''}
                  formatter={(v) => [`${fmtNum(Number(v))} butir`, 'Telur']}
                />
                <Bar dataKey="telur" name="Telur" fill="rgb(var(--brand-600))" radius={[4, 4, 0, 0]} />
              </BarChart>
            </ResponsiveContainer>
          </div>
        )}
      </div>

      <div className="grid gap-6 lg:grid-cols-2">
        <div className="rounded-2xl bg-white p-5 shadow">
          <h2 className="font-semibold text-gray-900">7 hari terakhir</h2>
          <table className="mt-3 w-full text-sm">
            <thead>
              <tr className="text-left text-xs text-gray-400">
                <th className="pb-2">Tanggal</th>
                <th className="pb-2 text-right">Telur</th>
                <th className="pb-2 text-right">Pendapatan</th>
              </tr>
            </thead>
            <tbody>
              {last7.map((r) => (
                <tr key={r.date} className="border-t">
                  <td className="py-2">{fmtDate(r.date)}</td>
                  <td className="py-2 text-right">{fmtNum(r.total_eggs)}</td>
                  <td className="py-2 text-right">{fmtRp(r.sales_revenue)}</td>
                </tr>
              ))}
              {last7.length === 0 && (
                <tr><td colSpan={3} className="py-3 text-center text-gray-400">Tidak ada data.</td></tr>
              )}
            </tbody>
          </table>
        </div>

        <div className="rounded-2xl bg-white p-5 shadow">
          <h2 className="font-semibold text-gray-900">Bulanan tahun berjalan</h2>
          <table className="mt-3 w-full text-sm">
            <thead>
              <tr className="text-left text-xs text-gray-400">
                <th className="pb-2">Bulan</th>
                <th className="pb-2 text-right">Telur</th>
                <th className="pb-2 text-right">Pendapatan</th>
              </tr>
            </thead>
            <tbody>
              {monthly.map((m) => (
                <tr key={`${m.year}-${m.month}`} className="border-t">
                  <td className="py-2">{m.month}/{String(m.year).slice(2)}</td>
                  <td className="py-2 text-right">{fmtNum(m.total_eggs)}</td>
                  <td className="py-2 text-right">{fmtRp(m.total_sales_revenue)}</td>
                </tr>
              ))}
              {monthly.length === 0 && (
                <tr><td colSpan={3} className="py-3 text-center text-gray-400">Tidak ada data.</td></tr>
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
