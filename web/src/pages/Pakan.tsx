import { useEffect, useState } from 'react';
import { useAuth } from '../lib/auth';
import { canWrite, createOne, deleteOne, fromLocalInput, getOne, nowLocalInput, toLocalInput, updateOne } from '../lib/crud';
import { fmtDate, toISODate } from '../lib/api';
import { useList } from '../hooks/useList';
import { Btn, ErrorBox, Field, FilterBar, Modal, PageHead, Pager, inputCls } from '../components/ui';

interface Feeding {
  id: number;
  date: string;
  feed_type: string;
  quantity_kg: number;
  notes?: string | null;
}

const emptyForm = () => ({ date: nowLocalInput(), feed_type: '', quantity_kg: '', notes: '' });

export default function Pakan() {
  const { user } = useAuth();
  const writable = canWrite(user);
  const today = new Date();
  const ago = new Date();
  ago.setDate(today.getDate() - 29);
  const [start, setStart] = useState(toISODate(ago));
  const [end, setEnd] = useState(toISODate(today));
  const [typeF, setTypeF] = useState('');

  const { rows, loading, loadingMore, error, hasMore, reload, loadMore } =
    useList<Feeding>('/feedings/', {
      start_date: start || undefined,
      end_date: end || undefined,
      feed_type: typeF || undefined,
    });

  const [stock, setStock] = useState<Record<string, number>>({});
  const [showForm, setShowForm] = useState(false);
  const [editing, setEditing] = useState<Feeding | null>(null);
  const [form, setForm] = useState(emptyForm());
  const [formErr, setFormErr] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  async function loadStock() {
    try {
      setStock(await getOne<Record<string, number>>('/feedings/stock'));
    } catch {
      setStock({});
    }
  }

  useEffect(() => {
    void loadStock();
  }, []);

  function openCreate() {
    setEditing(null);
    setForm(emptyForm());
    setFormErr(null);
    setShowForm(true);
  }

  function openEdit(f: Feeding) {
    setEditing(f);
    setForm({
      date: toLocalInput(f.date), feed_type: f.feed_type,
      quantity_kg: String(f.quantity_kg), notes: f.notes ?? '',
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
        feed_type: form.feed_type.trim(),
        quantity_kg: Number(form.quantity_kg) || 0,
        notes: form.notes || null,
      };
      if (editing) await updateOne(`/feedings/${editing.id}`, body);
      else await createOne('/feedings/', body);
      setShowForm(false);
      await Promise.all([reload(), loadStock()]);
    } catch (e) {
      setFormErr(e instanceof Error ? e.message : 'Gagal menyimpan');
    } finally {
      setSaving(false);
    }
  }

  async function onDelete(f: Feeding) {
    if (!window.confirm(`Hapus pemberian ${f.feed_type} ${f.quantity_kg} kg?`)) return;
    try {
      await deleteOne(`/feedings/${f.id}`);
      await Promise.all([reload(), loadStock()]);
    } catch (e) {
      alert(e instanceof Error ? e.message : 'Gagal menghapus');
    }
  }

  const stockKeys = Object.keys(stock);

  return (
    <div className="space-y-4">
      <PageHead
        title="🌾 Pemberian Pakan"
        action={writable && <Btn kind="primary" onClick={openCreate}>+ Beri pakan</Btn>}
      />

      <div className="rounded-2xl bg-white p-4 shadow">
        <h2 className="text-sm font-semibold text-gray-700">Sisa stok (global, per jenis)</h2>
        {stockKeys.length === 0 ? (
          <p className="mt-1 text-sm text-gray-400">Belum ada stok — catat pembelian di menu Biaya.</p>
        ) : (
          <div className="mt-2 flex flex-wrap gap-2">
            {stockKeys.map((k) => (
              <span key={k} className="rounded-full bg-amber-100 px-3 py-1 text-sm font-semibold text-amber-800">
                {k}: {stock[k]} kg
              </span>
            ))}
          </div>
        )}
      </div>

      <FilterBar>
        <Field label="Dari">
          <input type="date" value={start} onChange={(e) => setStart(e.target.value)} className={inputCls} />
        </Field>
        <Field label="Sampai">
          <input type="date" value={end} onChange={(e) => setEnd(e.target.value)} className={inputCls} />
        </Field>
        <Field label="Jenis">
          <input value={typeF} onChange={(e) => setTypeF(e.target.value)} placeholder="semua"
            list="feed-types" className={inputCls} />
          <datalist id="feed-types">
            {stockKeys.map((k) => <option key={k} value={k} />)}
          </datalist>
        </Field>
      </FilterBar>

      <ErrorBox msg={error} />
      {loading ? (
        <p className="py-6 text-center text-gray-500">Memuat…</p>
      ) : (
        <div className="space-y-2">
          {rows.map((f) => (
            <div key={f.id} className="flex flex-wrap items-center justify-between gap-2 rounded-2xl bg-white p-4 shadow">
              <div>
                <p className="font-semibold">{fmtDate(f.date)} · {f.feed_type}</p>
                <p className="text-sm text-gray-600">{f.quantity_kg} kg{f.notes ? ` · ${f.notes}` : ''}</p>
              </div>
              {writable && (
                <div className="flex gap-2">
                  <Btn onClick={() => openEdit(f)}>Ubah</Btn>
                  <Btn kind="danger" onClick={() => void onDelete(f)}>Hapus</Btn>
                </div>
              )}
            </div>
          ))}
          <Pager count={rows.length} hasMore={hasMore} loadingMore={loadingMore} onMore={loadMore} />
        </div>
      )}

      {showForm && (
        <Modal title={editing ? 'Ubah pemberian' : 'Beri pakan'} onClose={() => setShowForm(false)}>
          <div className="space-y-3">
            <ErrorBox msg={formErr} />
            <Field label="Tanggal & jam">
              <input type="datetime-local" value={form.date}
                onChange={(e) => setForm({ ...form, date: e.target.value })} className={inputCls} />
            </Field>
            <Field label="Jenis pakan">
              <input value={form.feed_type} onChange={(e) => setForm({ ...form, feed_type: e.target.value })}
                list="feed-types-form" className={inputCls} />
              <datalist id="feed-types-form">
                {stockKeys.map((k) => <option key={k} value={k} />)}
              </datalist>
            </Field>
            <Field label={`Jumlah (kg${form.feed_type && stock[form.feed_type] != null ? `, sisa ${stock[form.feed_type]} kg` : ''})`}>
              <input type="number" min={0} step="any" value={form.quantity_kg}
                onChange={(e) => setForm({ ...form, quantity_kg: e.target.value })} className={inputCls} />
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
