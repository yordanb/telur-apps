import { useCallback, useEffect, useState } from 'react';
import { fmtDate, fmtRp, toISODate } from '../lib/api';
import { list } from '../lib/crud';
import { ErrorBox, PageHead } from '../components/ui';

interface Sale {
  id: number;
  date: string;
  total_price: number;
}

interface Cost {
  id: number;
  date: string;
  category: string;
  description: string;
  amount: number;
}

interface Cash {
  id: number;
  date: string;
  direction: string;
  category: string;
  description: string;
  amount: number;
}

const PERIODS = [
  { days: 7, label: '7 hari' },
  { days: 30, label: '30 hari' },
  { days: 90, label: '90 hari' },
  { days: 0, label: 'Semua' },
];

// Meniru mobile (finance_screen.dart):
// pemasukan = penjualan telur + kas masuk;
// pengeluaran = SEMUA Biaya + kas keluar.
// Pemberian pakan tidak menyentuh kas.
export default function Keuangan() {
  const [days, setDays] = useState(30);
  const [sales, setSales] = useState<Sale[]>([]);
  const [costs, setCosts] = useState<Cost[]>([]);
  const [cash, setCash] = useState<Cash[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const q = days === 0 ? '' : `?start_date=${toISODate(
        new Date(Date.now() - (days - 1) * 86400000),
      )}&limit=1000`;
      const [s, c, k] = await Promise.all([
        list<Sale>(`/egg-sales/${q || '?limit=1000'}`),
        list<Cost>(`/cost-records/${q || '?limit=1000'}`),
        list<Cash>(`/cash-transactions/${q || '?limit=1000'}`),
      ]);
      setSales(s);
      setCosts(c);
      setCash(k);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Gagal memuat');
    } finally {
      setLoading(false);
    }
  }, [days]);

  useEffect(() => {
    void load();
  }, [load]);

  const incomeEgg = sales.reduce((a, s) => a + s.total_price, 0);
  const cashIn = cash.filter((t) => t.direction === 'masuk');
  const cashOut = cash.filter((t) => t.direction !== 'masuk');
  const incomeOther = cashIn.reduce((a, t) => a + t.amount, 0);
  const expenseCost = costs.reduce((a, c) => a + c.amount, 0);
  const expenseOther = cashOut.reduce((a, t) => a + t.amount, 0);
  const income = incomeEgg + incomeOther;
  const expense = expenseCost + expenseOther;
  const balance = income - expense;

  const sumBy = (items: { category: string; amount: number }[]) => {
    const m = new Map<string, number>();
    for (const it of items) m.set(it.category, (m.get(it.category) ?? 0) + it.amount);
    return [...m.entries()].sort((a, b) => b[1] - a[1]);
  };

  const recent = [
    ...sales.map((s) => ({ date: s.date, label: 'Penjualan telur', amount: s.total_price })),
    ...costs.map((c) => ({ date: c.date, label: `Biaya: ${c.description}`, amount: -c.amount })),
    ...cash.map((t) => ({
      date: t.date,
      label: `Kas: ${t.description}`,
      amount: t.direction === 'masuk' ? t.amount : -t.amount,
    })),
  ]
    .sort((a, b) => (a.date < b.date ? 1 : -1))
    .slice(0, 10);

  return (
    <div className="space-y-4">
      <PageHead title="💳 Keuangan" />
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
      ) : (
        <>
          <div className={`rounded-2xl p-5 shadow ${balance >= 0 ? 'bg-green-600' : 'bg-red-600'} text-white`}>
            <p className="text-sm opacity-80">Saldo periode</p>
            <p className="text-3xl font-bold">{fmtRp(balance)}</p>
            <div className="mt-2 flex gap-4 text-sm">
              <span>Masuk: <b>{fmtRp(income)}</b></span>
              <span>Keluar: <b>{fmtRp(expense)}</b></span>
            </div>
          </div>

          <div className="grid gap-4 lg:grid-cols-2">
            <div className="rounded-2xl bg-white p-5 shadow">
              <h2 className="font-semibold text-green-700">Rincian pemasukan</h2>
              <dl className="mt-2 space-y-1 text-sm">
                <div className="flex justify-between"><dt>Penjualan telur</dt><dd className="font-medium">{fmtRp(incomeEgg)}</dd></div>
                {sumBy(cashIn).map(([cat, v]) => (
                  <div key={cat} className="flex justify-between text-gray-600"><dt>{cat}</dt><dd>{fmtRp(v)}</dd></div>
                ))}
              </dl>
            </div>
            <div className="rounded-2xl bg-white p-5 shadow">
              <h2 className="font-semibold text-red-600">Rincian pengeluaran</h2>
              <dl className="mt-2 space-y-1 text-sm">
                {sumBy(costs).map(([cat, v]) => (
                  <div key={cat} className="flex justify-between"><dt>Biaya {cat}</dt><dd className="font-medium">{fmtRp(v)}</dd></div>
                ))}
                {sumBy(cashOut).map(([cat, v]) => (
                  <div key={cat} className="flex justify-between text-gray-600"><dt>Kas {cat}</dt><dd>{fmtRp(v)}</dd></div>
                ))}
              </dl>
            </div>
          </div>

          <div className="rounded-2xl bg-white p-5 shadow">
            <h2 className="font-semibold text-gray-900">Arus terakhir</h2>
            <ul className="mt-2 divide-y text-sm">
              {recent.map((r, i) => (
                <li key={i} className="flex items-center justify-between py-2">
                  <span className="text-gray-600">{fmtDate(r.date)} · {r.label}</span>
                  <span className={`font-semibold ${r.amount >= 0 ? 'text-green-700' : 'text-red-600'}`}>
                    {r.amount >= 0 ? '+' : '−'}{fmtRp(Math.abs(r.amount))}
                  </span>
                </li>
              ))}
              {recent.length === 0 && <li className="py-3 text-center text-gray-400">Tidak ada data.</li>}
            </ul>
            <p className="mt-3 text-xs text-gray-500">
              Catatan: pengeluaran dihitung dari data Biaya (pembelian pakan termasuk).
              Pemberian pakan mengatur stok dan tidak memengaruhi kas.
            </p>
          </div>
        </>
      )}
    </div>
  );
}
