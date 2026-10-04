import { useCallback, useEffect, useState } from 'react';
import {
  MONTH_NAMES, fmtDate, fmtNum, fmtRp, getDailyStats, getMonthlyStats, toISODate,
} from '../lib/api';
import type { DailyStat, MonthlyStat } from '../lib/api';

export default function Statistik() {
  const today = new Date();
  const ago30 = new Date();
  ago30.setDate(today.getDate() - 29);

  const [start, setStart] = useState(toISODate(ago30));
  const [end, setEnd] = useState(toISODate(today));
  const [year, setYear] = useState(today.getFullYear());
  const [daily, setDaily] = useState<DailyStat[]>([]);
  const [monthly, setMonthly] = useState<MonthlyStat[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const [d, m] = await Promise.all([getDailyStats(start, end), getMonthlyStats(year)]);
      setDaily([...d].reverse());
      setMonthly([...m].sort((a, b) => a.month - b.month));
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Gagal memuat');
    } finally {
      setLoading(false);
    }
  }, [start, end, year]);

  useEffect(() => {
    void load();
  }, [load]);

  const t = (pick: (r: DailyStat) => number) => daily.reduce((a, r) => a + pick(r), 0);

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold text-gray-900">📊 Statistik</h1>

      <div className="flex flex-wrap items-end gap-3 rounded-2xl bg-white p-4 shadow">
        <label className="text-sm">
          <span className="mb-1 block text-xs text-gray-500">Dari</span>
          <input type="date" value={start} onChange={(e) => setStart(e.target.value)}
            className="rounded-lg border border-gray-300 px-3 py-1.5" />
        </label>
        <label className="text-sm">
          <span className="mb-1 block text-xs text-gray-500">Sampai</span>
          <input type="date" value={end} onChange={(e) => setEnd(e.target.value)}
            className="rounded-lg border border-gray-300 px-3 py-1.5" />
        </label>
        <label className="text-sm">
          <span className="mb-1 block text-xs text-gray-500">Tahun (bulanan)</span>
          <input type="number" value={year} onChange={(e) => setYear(Number(e.target.value))}
            className="w-28 rounded-lg border border-gray-300 px-3 py-1.5" />
        </label>
        <button onClick={() => void load()}
          className="rounded-lg bg-brand-600 px-4 py-2 text-sm font-semibold text-white hover:bg-brand-700">
          Tampilkan
        </button>
      </div>

      {error && <div className="rounded-xl bg-red-50 p-4 text-sm text-red-700">{error}</div>}
      {loading ? (
        <p className="py-6 text-center text-gray-500">Memuat…</p>
      ) : (
        <>
          <div className="overflow-x-auto rounded-2xl bg-white shadow">
            <table className="w-full min-w-[640px] text-sm">
              <thead>
                <tr className="bg-gray-50 text-left text-xs text-gray-500">
                  <th className="px-4 py-2">Tanggal</th>
                  <th className="px-4 py-2 text-right">Telur</th>
                  <th className="px-4 py-2 text-right">Baik</th>
                  <th className="px-4 py-2 text-right">Rusak</th>
                  <th className="px-4 py-2 text-right">Biaya pakan</th>
                  <th className="px-4 py-2 text-right">Biaya lain</th>
                  <th className="px-4 py-2 text-right">Pendapatan</th>
                </tr>
              </thead>
              <tbody>
                {daily.map((r) => (
                  <tr key={r.date} className="border-t">
                    <td className="px-4 py-2">{fmtDate(r.date)}</td>
                    <td className="px-4 py-2 text-right">{fmtNum(r.total_eggs)}</td>
                    <td className="px-4 py-2 text-right">{fmtNum(r.good_eggs)}</td>
                    <td className="px-4 py-2 text-right">{fmtNum(r.bad_eggs)}</td>
                    <td className="px-4 py-2 text-right">{fmtRp(r.feed_cost)}</td>
                    <td className="px-4 py-2 text-right">{fmtRp(r.other_cost)}</td>
                    <td className="px-4 py-2 text-right">{fmtRp(r.sales_revenue)}</td>
                  </tr>
                ))}
                {daily.length === 0 && (
                  <tr><td colSpan={7} className="px-4 py-4 text-center text-gray-400">Tidak ada data.</td></tr>
                )}
              </tbody>
              {daily.length > 0 && (
                <tfoot>
                  <tr className="border-t-2 bg-gray-50 font-semibold">
                    <td className="px-4 py-2">Total</td>
                    <td className="px-4 py-2 text-right">{fmtNum(t((r) => r.total_eggs))}</td>
                    <td className="px-4 py-2 text-right">{fmtNum(t((r) => r.good_eggs))}</td>
                    <td className="px-4 py-2 text-right">{fmtNum(t((r) => r.bad_eggs))}</td>
                    <td className="px-4 py-2 text-right">{fmtRp(t((r) => r.feed_cost))}</td>
                    <td className="px-4 py-2 text-right">{fmtRp(t((r) => r.other_cost))}</td>
                    <td className="px-4 py-2 text-right">{fmtRp(t((r) => r.sales_revenue))}</td>
                  </tr>
                </tfoot>
              )}
            </table>
          </div>

          <div className="overflow-x-auto rounded-2xl bg-white shadow">
            <table className="w-full min-w-[720px] text-sm">
              <thead>
                <tr className="bg-gray-50 text-left text-xs text-gray-500">
                  <th className="px-4 py-2">Bulan {year}</th>
                  <th className="px-4 py-2 text-right">Telur</th>
                  <th className="px-4 py-2 text-right">Rata2/hari</th>
                  <th className="px-4 py-2 text-right">Pakan</th>
                  <th className="px-4 py-2 text-right">Lain</th>
                  <th className="px-4 py-2 text-right">Penjualan</th>
                  <th className="px-4 py-2 text-right">Kas +/−</th>
                </tr>
              </thead>
              <tbody>
                {monthly.map((m) => (
                  <tr key={`${m.year}-${m.month}`} className="border-t">
                    <td className="px-4 py-2">{MONTH_NAMES[m.month - 1]}</td>
                    <td className="px-4 py-2 text-right">{fmtNum(m.total_eggs)}</td>
                    <td className="px-4 py-2 text-right">{m.avg_daily_eggs}</td>
                    <td className="px-4 py-2 text-right">{fmtRp(m.total_feed_cost)}</td>
                    <td className="px-4 py-2 text-right">{fmtRp(m.total_other_cost)}</td>
                    <td className="px-4 py-2 text-right">{fmtRp(m.total_sales_revenue)}</td>
                    <td className="px-4 py-2 text-right">
                      +{fmtRp(m.total_other_income)} / −{fmtRp(m.total_other_expense)}
                    </td>
                  </tr>
                ))}
                {monthly.length === 0 && (
                  <tr><td colSpan={7} className="px-4 py-4 text-center text-gray-400">Tidak ada data.</td></tr>
                )}
              </tbody>
            </table>
          </div>
        </>
      )}
    </div>
  );
}
