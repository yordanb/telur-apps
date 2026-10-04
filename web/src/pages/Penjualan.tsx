import { useState } from 'react';
import { useAuth } from '../lib/auth';
import {
  SALE_UNITS, canWrite, createOne, deleteOne,
  fromLocalInput, nowLocalInput, toLocalInput, updateOne,
} from '../lib/crud';
import { fmtDate, fmtNum, fmtRp, toISODate } from '../lib/api';
import { useList } from '../hooks/useList';
import { Btn, ErrorBox, Field, FilterBar, Modal, PageHead, Pager, inputCls } from '../components/ui';

interface Sale {
  id: number;
  date: string;
  unit: string;
  quantity: number;
  price_per_unit: number;
  total_price: number;
  notes?: string | null;
}

const emptyForm = () => ({ date: nowLocalInput(), unit: 'butir', quantity: '', price_per_unit: '', notes: '' });

export default function Penjualan() {
  const { user } = useAuth();
  const writable = canWrite(user);
  const today = new Date();
  const ago = new Date();
  ago.setDate(today.getDate() - 29);
  const [start, setStart] = useState(toISODate(ago));
  const [end, setEnd] = useState(toISODate(today));
  const [unitF, setUnitF] = useState('');

  const { rows, loading, loadingMore, error, hasMore, reload, loadMore } =
    useList<Sale>('/egg-sales/', {
      start_date: start || undefined,
      end_date: end || undefined,
      unit: unitF || undefined,
    });

  const [showForm, setShowForm] = useState(false);
  const [editing, setEditing] = useState<Sale | null>(null);
  const [form, setForm] = useState(emptyForm());
  const [formErr, setFormErr] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  function openCreate() {
    setEditing(null);
    setForm(emptyForm());
    setFormErr(null);
    setShowForm(true);
  }

  function openEdit(s: Sale) {
    setEditing(s);
    setForm({
      date: toLocalInput(s.date), unit: s.unit,
      quantity: String(s.quantity), price_per_unit: String(s.price_per_unit),
      notes: s.notes ?? '',
    });
    setFormErr(null);
    setShowForm(true);
  }

  async function onSave() {
    setSaving(true);
    setFormErr(null);
    if (!(Number(form.quantity) > 0)) {
      setFormErr('Jumlah harus lebih dari 0');
      setSaving(false);
      return;
    }
    if (!(Number(form.price_per_unit) >= 0)) {
      setFormErr('Harga tidak boleh negatif');
      setSaving(false);
      return;
    }
    try {
      const body = {
        date: fromLocalInput(form.date),
        unit: form.unit,
        quantity: Number(form.quantity) || 0,
        price_per_unit: Number(form.price_per_unit) || 0,
        notes: form.notes || null,
      };
      if (editing) await updateOne(`/egg-sales/${editing.id}`, body);
      else await createOne('/egg-sales/', body);
      setShowForm(false);
      await reload();
    } catch (e) {
      setFormErr(e instanceof Error ? e.message : 'Gagal menyimpan');
    } finally {
      setSaving(false);
    }
  }

  async function onDelete(s: Sale) {
    if (!window.confirm(`Hapus penjualan ${fmtDate(s.date)} (${fmtRp(s.total_price)})?`)) return;
    try {
      await deleteOne(`/egg-sales/${s.id}`);
      await reload();
    } catch (e) {
      alert(e instanceof Error ? e.message : 'Gagal menghapus');
    }
  }

  const qtyLabel = form.unit === 'kg' ? 'Jumlah (kg)' : 'Jumlah (butir)';
  const priceLabel = form.unit === 'kg' ? 'Harga/kg (Rp)' : 'Harga/butir (Rp)';

  return (
    <div className="space-y-4">
      <PageHead
        title="💰 Penjualan Telur"
        action={writable && <Btn kind="primary" onClick={openCreate}>+ Catat jual</Btn>}
      />
      <FilterBar>
        <Field label="Dari">
          <input type="date" value={start} onChange={(e) => setStart(e.target.value)} className={inputCls} />
        </Field>
        <Field label="Sampai">
          <input type="date" value={end} onChange={(e) => setEnd(e.target.value)} className={inputCls} />
        </Field>
        <Field label="Satuan">
          <select value={unitF} onChange={(e) => setUnitF(e.target.value)} className={inputCls}>
            <option value="">Semua</option>
            {SALE_UNITS.map((u) => <option key={u} value={u}>{u}</option>)}
          </select>
        </Field>
      </FilterBar>

      <ErrorBox msg={error} />
      {loading ? (
        <p className="py-6 text-center text-gray-500">Memuat…</p>
      ) : (
        <div className="space-y-2">
          {rows.map((s) => (
            <div key={s.id} className="flex flex-wrap items-center justify-between gap-2 rounded-2xl bg-white p-4 shadow">
              <div>
                <p className="font-semibold">{fmtDate(s.date)}</p>
                <p className="text-sm text-gray-600">
                  {s.unit === 'kg' ? `${s.quantity} kg` : `${fmtNum(s.quantity)} butir`} @ {fmtRp(s.price_per_unit)}
                  {s.notes ? ` · ${s.notes}` : ''}
                </p>
                <p className="text-sm font-bold text-green-700">{fmtRp(s.total_price)}</p>
              </div>
              {writable && (
                <div className="flex gap-2">
                  <Btn onClick={() => openEdit(s)}>Ubah</Btn>
                  <Btn kind="danger" onClick={() => void onDelete(s)}>Hapus</Btn>
                </div>
              )}
            </div>
          ))}
          <Pager count={rows.length} hasMore={hasMore} loadingMore={loadingMore} onMore={loadMore} />
        </div>
      )}

      {showForm && (
        <Modal title={editing ? 'Ubah penjualan' : 'Catat penjualan'} onClose={() => setShowForm(false)}>
          <div className="space-y-3">
            <ErrorBox msg={formErr} />
            <Field label="Tanggal & jam">
              <input type="datetime-local" value={form.date}
                onChange={(e) => setForm({ ...form, date: e.target.value })} className={inputCls} />
            </Field>
            <Field label="Satuan">
              <select value={form.unit} onChange={(e) => setForm({ ...form, unit: e.target.value })} className={inputCls}>
                {SALE_UNITS.map((u) => <option key={u} value={u}>{u}</option>)}
              </select>
            </Field>
            <div className="grid grid-cols-2 gap-2">
              <Field label={qtyLabel}>
                <input type="number" min={0} step="any" value={form.quantity}
                  onChange={(e) => setForm({ ...form, quantity: e.target.value })} className={inputCls} />
              </Field>
              <Field label={priceLabel}>
                <input type="number" min={0} step="any" value={form.price_per_unit}
                  onChange={(e) => setForm({ ...form, price_per_unit: e.target.value })} className={inputCls} />
              </Field>
            </div>
            <p className="text-sm text-gray-600">
              Total dihitung server: <b>{fmtRp((Number(form.quantity) || 0) * (Number(form.price_per_unit) || 0))}</b>
            </p>
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
