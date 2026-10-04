import { useState } from 'react';
import { useAuth } from '../lib/auth';
import {
  CASH_DIRECTIONS, CASH_IN_CATS, CASH_OUT_CATS, canWrite, createOne, deleteOne,
  fromLocalInput, nowLocalInput, toLocalInput, updateOne,
} from '../lib/crud';
import { fmtDate, fmtRp, toISODate } from '../lib/api';
import { useList } from '../hooks/useList';
import { Btn, ErrorBox, Field, FilterBar, Modal, PageHead, Pager, inputCls } from '../components/ui';

interface Cash {
  id: number;
  date: string;
  direction: string;
  category: string;
  description: string;
  amount: number;
  notes?: string | null;
}

const emptyForm = () => ({
  date: nowLocalInput(), direction: 'masuk', category: CASH_IN_CATS[0],
  description: '', amount: '', notes: '',
});

export default function Kas() {
  const { user } = useAuth();
  const writable = canWrite(user);
  const today = new Date();
  const ago = new Date();
  ago.setDate(today.getDate() - 29);
  const [start, setStart] = useState(toISODate(ago));
  const [end, setEnd] = useState(toISODate(today));
  const [dirF, setDirF] = useState('');

  const { rows, loading, loadingMore, error, hasMore, reload, loadMore } =
    useList<Cash>('/cash-transactions/', {
      start_date: start || undefined,
      end_date: end || undefined,
      direction: dirF || undefined,
    });

  const [showForm, setShowForm] = useState(false);
  const [editing, setEditing] = useState<Cash | null>(null);
  const [form, setForm] = useState(emptyForm());
  const [formErr, setFormErr] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  const cats = form.direction === 'masuk' ? CASH_IN_CATS : CASH_OUT_CATS;

  function openCreate() {
    setEditing(null);
    setForm(emptyForm());
    setFormErr(null);
    setShowForm(true);
  }

  function openEdit(c: Cash) {
    setEditing(c);
    setForm({
      date: toLocalInput(c.date), direction: c.direction, category: c.category,
      description: c.description, amount: String(c.amount), notes: c.notes ?? '',
    });
    setFormErr(null);
    setShowForm(true);
  }

  async function onSave() {
    setSaving(true);
    setFormErr(null);
    try {
      const body = {
        date: fromLocalInput(form.date),
        direction: form.direction,
        category: form.category,
        description: form.description.trim(),
        amount: Number(form.amount) || 0,
        notes: form.notes || null,
      };
      if (editing) await updateOne(`/cash-transactions/${editing.id}`, body);
      else await createOne('/cash-transactions/', body);
      setShowForm(false);
      await reload();
    } catch (e) {
      setFormErr(e instanceof Error ? e.message : 'Gagal menyimpan');
    } finally {
      setSaving(false);
    }
  }

  async function onDelete(c: Cash) {
    if (!window.confirm(`Hapus kas ${c.direction} "${c.description}" (${fmtRp(c.amount)})?`)) return;
    try {
      await deleteOne(`/cash-transactions/${c.id}`);
      await reload();
    } catch (e) {
      alert(e instanceof Error ? e.message : 'Gagal menghapus');
    }
  }

  return (
    <div className="space-y-4">
      <PageHead
        title="👛 Kas Manual"
        action={writable && <Btn kind="primary" onClick={openCreate}>+ Catat kas</Btn>}
      />
      <FilterBar>
        <Field label="Dari">
          <input type="date" value={start} onChange={(e) => setStart(e.target.value)} className={inputCls} />
        </Field>
        <Field label="Sampai">
          <input type="date" value={end} onChange={(e) => setEnd(e.target.value)} className={inputCls} />
        </Field>
        <Field label="Arah">
          <select value={dirF} onChange={(e) => setDirF(e.target.value)} className={inputCls}>
            <option value="">Semua</option>
            {CASH_DIRECTIONS.map((d) => <option key={d} value={d}>{d}</option>)}
          </select>
        </Field>
      </FilterBar>

      <ErrorBox msg={error} />
      {loading ? (
        <p className="py-6 text-center text-gray-500">Memuat…</p>
      ) : (
        <div className="space-y-2">
          {rows.map((c) => (
            <div key={c.id} className="flex flex-wrap items-center justify-between gap-2 rounded-2xl bg-white p-4 shadow">
              <div>
                <p className="font-semibold">
                  {fmtDate(c.date)} ·{' '}
                  <span className={`rounded-full px-2 py-0.5 text-xs font-semibold ${
                    c.direction === 'masuk' ? 'bg-green-100 text-green-700' : 'bg-red-100 text-red-600'
                  }`}>{c.direction}</span>
                </p>
                <p className="text-sm text-gray-600">{c.category} · {c.description}</p>
                <p className={`text-sm font-bold ${c.direction === 'masuk' ? 'text-green-700' : 'text-red-600'}`}>
                  {c.direction === 'masuk' ? '+' : '−'}{fmtRp(c.amount)}
                </p>
              </div>
              {writable && (
                <div className="flex gap-2">
                  <Btn onClick={() => openEdit(c)}>Ubah</Btn>
                  <Btn kind="danger" onClick={() => void onDelete(c)}>Hapus</Btn>
                </div>
              )}
            </div>
          ))}
          <Pager count={rows.length} hasMore={hasMore} loadingMore={loadingMore} onMore={loadMore} />
        </div>
      )}

      {showForm && (
        <Modal title={editing ? 'Ubah kas' : 'Catat kas'} onClose={() => setShowForm(false)}>
          <div className="space-y-3">
            <ErrorBox msg={formErr} />
            <Field label="Tanggal & jam">
              <input type="datetime-local" value={form.date}
                onChange={(e) => setForm({ ...form, date: e.target.value })} className={inputCls} />
            </Field>
            <div className="grid grid-cols-2 gap-2">
              <Field label="Arah">
                <select
                  value={form.direction}
                  onChange={(e) => {
                    const d = e.target.value;
                    setForm({ ...form, direction: d, category: d === 'masuk' ? CASH_IN_CATS[0] : CASH_OUT_CATS[0] });
                  }}
                  className={inputCls}>
                  {CASH_DIRECTIONS.map((d) => <option key={d} value={d}>{d}</option>)}
                </select>
              </Field>
              <Field label="Kategori">
                <select value={form.category} onChange={(e) => setForm({ ...form, category: e.target.value })} className={inputCls}>
                  {cats.map((c) => <option key={c} value={c}>{c}</option>)}
                </select>
              </Field>
            </div>
            <Field label="Deskripsi">
              <input value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} className={inputCls} />
            </Field>
            <Field label="Jumlah (Rp, > 0)">
              <input type="number" min={0} step="any" value={form.amount}
                onChange={(e) => setForm({ ...form, amount: e.target.value })} className={inputCls} />
            </Field>
            <Field label="Catatan (opsional)">
              <input value={form.notes} onChange={(e) => setForm({ ...form, notes: e.target.value })} className={inputCls} />
            </Field>
            <Btn kind="primary" className="w-full" disabled={saving} onClick={() => void onSave()}>
              {saving ? 'Menyimpan…' : 'Simpan'}
            </Btn>
          </div>
        </Modal>
      )}
    </div>
  );
}
