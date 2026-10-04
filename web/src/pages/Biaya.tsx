import { useState } from 'react';
import { useAuth } from '../lib/auth';
import {
  COST_CATEGORIES, OP_SUBCATEGORIES, canWrite, checkRequired, createOne, deleteOne,
  fromLocalInput, nowLocalInput, toLocalInput, updateOne,
} from '../lib/crud';
import { fmtDate, fmtRp, toISODate } from '../lib/api';
import { useList } from '../hooks/useList';
import { Btn, ErrorBox, Field, FilterBar, Modal, PageHead, Pager, inputCls } from '../components/ui';

interface Cost {
  id: number;
  date: string;
  category: string;
  subcategory?: string | null;
  description: string;
  amount: number;
  feed_type?: string | null;
  quantity_kg?: number | null;
  price_per_kg?: number | null;
  notes?: string | null;
}

const emptyForm = () => ({
  date: nowLocalInput(), category: 'pakan', subcategory: OP_SUBCATEGORIES[0],
  description: '', amount: '', feed_type: '', quantity_kg: '', price_per_kg: '', notes: '',
});

export default function Biaya() {
  const { user } = useAuth();
  const writable = canWrite(user);
  const today = new Date();
  const ago = new Date();
  ago.setDate(today.getDate() - 29);
  const [start, setStart] = useState(toISODate(ago));
  const [end, setEnd] = useState(toISODate(today));
  const [catF, setCatF] = useState('');

  const { rows, loading, loadingMore, error, hasMore, reload, loadMore } =
    useList<Cost>('/cost-records/', {
      start_date: start || undefined,
      end_date: end || undefined,
      category: catF || undefined,
    });

  const [showForm, setShowForm] = useState(false);
  const [editing, setEditing] = useState<Cost | null>(null);
  const [form, setForm] = useState(emptyForm());
  const [formErr, setFormErr] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  function openCreate() {
    setEditing(null);
    setForm(emptyForm());
    setFormErr(null);
    setShowForm(true);
  }

  function openEdit(c: Cost) {
    setEditing(c);
    setForm({
      date: toLocalInput(c.date), category: c.category,
      subcategory: c.subcategory ?? OP_SUBCATEGORIES[0],
      description: c.description, amount: String(c.amount),
      feed_type: c.feed_type ?? '',
      quantity_kg: c.quantity_kg != null ? String(c.quantity_kg) : '',
      price_per_kg: c.price_per_kg != null ? String(c.price_per_kg) : '',
      notes: c.notes ?? '',
    });
    setFormErr(null);
    setShowForm(true);
  }

  const isPakan = form.category === 'pakan';
  const isOp = form.category === 'operasional';
  const calcAmount = (Number(form.quantity_kg) || 0) * (Number(form.price_per_kg) || 0);

  async function onSave() {
    setSaving(true);
    setFormErr(null);
    const missing = checkRequired([
      [form.description, 'Deskripsi'],
      ...(isPakan ? [[form.feed_type, 'Jenis pakan'] as [string, string]] : []),
    ]);
    const qty = Number(form.quantity_kg) || 0;
    const price = Number(form.price_per_kg) || 0;
    const amount = Number(form.amount) || 0;
    const invalid =
      missing ??
      (isPakan
        ? qty <= 0
          ? 'Jumlah (kg) harus lebih dari 0'
          : price <= 0
            ? 'Harga/kg harus lebih dari 0'
            : null
        : amount <= 0
          ? 'Jumlah (Rp) harus lebih dari 0'
          : null);
    if (invalid) {
      setFormErr(invalid);
      setSaving(false);
      return;
    }
    try {
      const body = {
        date: fromLocalInput(form.date),
        category: form.category,
        subcategory: isOp ? form.subcategory : null,
        description: form.description.trim(),
        amount: isPakan ? calcAmount : Number(form.amount) || 0,
        feed_type: isPakan ? form.feed_type.trim() || null : null,
        quantity_kg: isPakan ? Number(form.quantity_kg) || 0 : null,
        price_per_kg: isPakan ? Number(form.price_per_kg) || 0 : null,
        notes: form.notes || null,
      };
      if (editing) await updateOne(`/cost-records/${editing.id}`, body);
      else await createOne('/cost-records/', body);
      setShowForm(false);
      await reload();
    } catch (e) {
      setFormErr(e instanceof Error ? e.message : 'Gagal menyimpan');
    } finally {
      setSaving(false);
    }
  }

  async function onDelete(c: Cost) {
    if (!window.confirm(`Hapus biaya "${c.description}" (${fmtRp(c.amount)})?`)) return;
    try {
      await deleteOne(`/cost-records/${c.id}`);
      await reload();
    } catch (e) {
      alert(e instanceof Error ? e.message : 'Gagal menghapus');
    }
  }

  return (
    <div className="space-y-4">
      <PageHead
        title="🧾 Biaya"
        action={writable && <Btn kind="primary" onClick={openCreate}>+ Catat biaya</Btn>}
      />
      <FilterBar>
        <Field label="Dari">
          <input type="date" value={start} onChange={(e) => setStart(e.target.value)} className={inputCls} />
        </Field>
        <Field label="Sampai">
          <input type="date" value={end} onChange={(e) => setEnd(e.target.value)} className={inputCls} />
        </Field>
        <Field label="Kategori">
          <select value={catF} onChange={(e) => setCatF(e.target.value)} className={inputCls}>
            <option value="">Semua</option>
            {COST_CATEGORIES.map((c) => <option key={c} value={c}>{c}</option>)}
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
                  {fmtDate(c.date)} · <span className="rounded-full bg-gray-100 px-2 py-0.5 text-xs">{c.category}</span>
                </p>
                <p className="text-sm text-gray-600">
                  {c.description}
                  {c.subcategory ? ` (${c.subcategory})` : ''}
                  {c.category === 'pakan' && c.feed_type ? ` · ${c.feed_type} ${c.quantity_kg} kg` : ''}
                </p>
                <p className="text-sm font-bold text-gray-900">{fmtRp(c.amount)}</p>
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
        <Modal title={editing ? 'Ubah biaya' : 'Catat biaya'} onClose={() => setShowForm(false)}>
          <div className="space-y-3">
            <ErrorBox msg={formErr} />
            <Field label="Tanggal & jam">
              <input type="datetime-local" value={form.date}
                onChange={(e) => setForm({ ...form, date: e.target.value })} className={inputCls} />
            </Field>
            <Field label="Kategori">
              <select value={form.category} onChange={(e) => setForm({ ...form, category: e.target.value })} className={inputCls}>
                {COST_CATEGORIES.map((c) => <option key={c} value={c}>{c}</option>)}
              </select>
            </Field>
            {isOp && (
              <Field label="Subkategori operasional">
                <select value={form.subcategory} onChange={(e) => setForm({ ...form, subcategory: e.target.value })} className={inputCls}>
                  {OP_SUBCATEGORIES.map((s) => <option key={s} value={s}>{s}</option>)}
                </select>
              </Field>
            )}
            <Field label="Deskripsi">
              <input value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} className={inputCls} />
            </Field>
            {isPakan ? (
              <>
                <Field label="Jenis pakan">
                  <input value={form.feed_type} onChange={(e) => setForm({ ...form, feed_type: e.target.value })} className={inputCls} />
                </Field>
                <div className="grid grid-cols-2 gap-2">
                  <Field label="Jumlah (kg)">
                    <input type="number" min={0} step="any" value={form.quantity_kg}
                      onChange={(e) => setForm({ ...form, quantity_kg: e.target.value })} className={inputCls} />
                  </Field>
                  <Field label="Harga/kg (Rp)">
                    <input type="number" min={0} step="any" value={form.price_per_kg}
                      onChange={(e) => setForm({ ...form, price_per_kg: e.target.value })} className={inputCls} />
                  </Field>
                </div>
                <p className="text-sm text-gray-600">Total otomatis: <b>{fmtRp(calcAmount)}</b></p>
              </>
            ) : (
              <Field label="Jumlah (Rp)">
                <input type="number" min={0} step="any" value={form.amount}
                  onChange={(e) => setForm({ ...form, amount: e.target.value })} className={inputCls} />
              </Field>
            )}
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
