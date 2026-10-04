import { useEffect, useState } from 'react';
import { useAuth } from '../lib/auth';
import { canWrite, createOne, deleteOne, fromLocalInput, list, nowLocalInput, toLocalInput, updateOne } from '../lib/crud';
import { fmtDate, fmtNum, toISODate } from '../lib/api';
import { useList } from '../hooks/useList';
import { Btn, ErrorBox, Field, FilterBar, Modal, PageHead, Pager, inputCls } from '../components/ui';

interface ProdDetail {
  id: number;
  chicken_id: number;
  eggs: number;
  chicken_code: string;
  chicken_name?: string | null;
}

interface Production {
  id: number;
  date: string;
  total_eggs: number;
  good_eggs: number;
  bad_eggs: number;
  weight_avg?: number | null;
  notes?: string | null;
  details: ProdDetail[];
}

interface ChickenOpt {
  id: number;
  code: string;
  name?: string | null;
}

interface DetailRow {
  chicken_id: string;
  eggs: string;
}

const emptyForm = () => ({
  date: nowLocalInput(),
  total_eggs: '',
  good_eggs: '',
  bad_eggs: '0',
  weight_avg: '',
  notes: '',
  details: [] as DetailRow[],
});

export default function Produksi() {
  const { user } = useAuth();
  const writable = canWrite(user);
  const today = new Date();
  const ago = new Date();
  ago.setDate(today.getDate() - 29);
  const [start, setStart] = useState(toISODate(ago));
  const [end, setEnd] = useState(toISODate(today));

  const { rows, loading, loadingMore, error, hasMore, reload, loadMore } =
    useList<Production>('/egg-productions/', { start_date: start || undefined, end_date: end || undefined });

  const [chickens, setChickens] = useState<ChickenOpt[]>([]);
  const [showForm, setShowForm] = useState(false);
  const [editing, setEditing] = useState<Production | null>(null);
  const [form, setForm] = useState(emptyForm());
  const [formErr, setFormErr] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    list<ChickenOpt>('/chickens/?skip=0&limit=200')
      .then((c) => setChickens(Array.isArray(c) ? c : []))
      .catch(() => setChickens([]));
  }, []);

  function openCreate() {
    setEditing(null);
    setForm(emptyForm());
    setFormErr(null);
    setShowForm(true);
  }

  function openEdit(p: Production) {
    setEditing(p);
    setForm({
      date: toLocalInput(p.date),
      total_eggs: String(p.total_eggs),
      good_eggs: String(p.good_eggs),
      bad_eggs: String(p.bad_eggs),
      weight_avg: p.weight_avg != null ? String(p.weight_avg) : '',
      notes: p.notes ?? '',
      details: (p.details ?? []).map((d) => ({ chicken_id: String(d.chicken_id), eggs: String(d.eggs) })),
    });
    setFormErr(null);
    setShowForm(true);
  }

  const detailTotal = form.details.reduce((a, d) => a + (Number(d.eggs) || 0), 0);
  const useDetails = form.details.length > 0;

  async function onSave() {
    setFormErr(null);
    setSaving(true);
    try {
      const details = form.details
        .filter((d) => d.chicken_id && Number(d.eggs) > 0)
        .map((d) => ({ chicken_id: Number(d.chicken_id), eggs: Number(d.eggs) }));
      const body = {
        date: fromLocalInput(form.date),
        total_eggs: Number(form.total_eggs) || 0,
        good_eggs: Number(form.good_eggs) || 0,
        bad_eggs: Number(form.bad_eggs) || 0,
        weight_avg: form.weight_avg === '' ? null : Number(form.weight_avg),
        notes: form.notes || null,
        ...(details.length > 0 ? { details } : {}),
      };
      if (editing) await updateOne(`/egg-productions/${editing.id}`, body);
      else await createOne('/egg-productions/', body);
      setShowForm(false);
      await reload();
    } catch (e) {
      setFormErr(e instanceof Error ? e.message : 'Gagal menyimpan');
    } finally {
      setSaving(false);
    }
  }

  async function onDelete(p: Production) {
    if (!window.confirm(`Hapus catatan ${fmtDate(p.date)} (${fmtNum(p.total_eggs)} butir)?`)) return;
    try {
      await deleteOne(`/egg-productions/${p.id}`);
      await reload();
    } catch (e) {
      alert(e instanceof Error ? e.message : 'Gagal menghapus');
    }
  }

  return (
    <div className="space-y-4">
      <PageHead
        title="🥚 Produksi Telur"
        action={writable && <Btn kind="primary" onClick={openCreate}>+ Catat</Btn>}
      />
      <FilterBar>
        <Field label="Dari">
          <input type="date" value={start} onChange={(e) => setStart(e.target.value)} className={inputCls} />
        </Field>
        <Field label="Sampai">
          <input type="date" value={end} onChange={(e) => setEnd(e.target.value)} className={inputCls} />
        </Field>
      </FilterBar>

      <ErrorBox msg={error} />
      {loading ? (
        <p className="py-6 text-center text-gray-500">Memuat…</p>
      ) : (
        <div className="space-y-2">
          {rows.map((p) => (
            <div key={p.id} className="rounded-2xl bg-white p-4 shadow">
              <div className="flex flex-wrap items-start justify-between gap-2">
                <div>
                  <p className="font-semibold text-gray-900">{fmtDate(p.date)}</p>
                  <p className="text-sm text-gray-600">
                    Total <b>{fmtNum(p.total_eggs)}</b> · Baik {fmtNum(p.good_eggs)} · Rusak {fmtNum(p.bad_eggs)}
                    {p.weight_avg != null && <> · {p.weight_avg} g</>}
                  </p>
                  {p.details && p.details.length > 0 && (
                    <p className="mt-1 text-xs text-gray-500">
                      {p.details.map((d) => `${d.chicken_code} ×${d.eggs}`).join(' · ')}
                    </p>
                  )}
                  {p.notes && <p className="mt-1 text-xs italic text-gray-500">{p.notes}</p>}
                </div>
                {writable && (
                  <div className="flex gap-2">
                    <Btn onClick={() => openEdit(p)}>Ubah</Btn>
                    <Btn kind="danger" onClick={() => void onDelete(p)}>Hapus</Btn>
                  </div>
                )}
              </div>
            </div>
          ))}
          <Pager count={rows.length} hasMore={hasMore} loadingMore={loadingMore} onMore={loadMore} />
        </div>
      )}

      {showForm && (
        <Modal title={editing ? 'Ubah produksi' : 'Catat produksi'} onClose={() => setShowForm(false)}>
          <div className="space-y-3">
            <ErrorBox msg={formErr} />
            <Field label="Tanggal & jam">
              <input type="datetime-local" value={form.date}
                onChange={(e) => setForm({ ...form, date: e.target.value })} className={inputCls} />
            </Field>
            <div className="grid grid-cols-3 gap-2">
              <Field label={useDetails ? 'Total (otomatis)' : 'Total butir'}>
                <input type="number" min={0} value={useDetails ? detailTotal : form.total_eggs}
                  disabled={useDetails}
                  onChange={(e) => setForm({ ...form, total_eggs: e.target.value })} className={inputCls} />
              </Field>
              <Field label={useDetails ? 'Baik (otomatis)' : 'Baik'}>
                <input type="number" min={0} value={useDetails ? detailTotal : form.good_eggs}
                  disabled={useDetails}
                  onChange={(e) => setForm({ ...form, good_eggs: e.target.value })} className={inputCls} />
              </Field>
              <Field label="Rusak">
                <input type="number" min={0} value={form.bad_eggs}
                  onChange={(e) => setForm({ ...form, bad_eggs: e.target.value })} className={inputCls} />
              </Field>
            </div>
            <Field label="Berat rata-rata (gram, opsional)">
              <input type="number" min={0} step="any" value={form.weight_avg}
                onChange={(e) => setForm({ ...form, weight_avg: e.target.value })} className={inputCls} />
            </Field>

            <div>
              <p className="mb-1 text-xs font-medium text-gray-600">Rincian per ayam (opsional — total mengikuti rincian)</p>
              <div className="space-y-2">
                {form.details.map((d, i) => (
                  <div key={i} className="flex gap-2">
                    <select value={d.chicken_id}
                      onChange={(e) => setForm({
                        ...form,
                        details: form.details.map((x, j) => (j === i ? { ...x, chicken_id: e.target.value } : x)),
                      })}
                      className={inputCls}>
                      <option value="">— pilih ayam —</option>
                      {chickens.map((c) => (
                        <option key={c.id} value={c.id}>{c.code}{c.name ? ` · ${c.name}` : ''}</option>
                      ))}
                    </select>
                    <input type="number" min={1} placeholder="butir" value={d.eggs}
                      onChange={(e) => setForm({
                        ...form,
                        details: form.details.map((x, j) => (j === i ? { ...x, eggs: e.target.value } : x)),
                      })}
                      className={`${inputCls} w-24`} />
                    <Btn kind="danger" onClick={() => setForm({
                      ...form, details: form.details.filter((_, j) => j !== i),
                    })}>×</Btn>
                  </div>
                ))}
                <Btn onClick={() => setForm({ ...form, details: [...form.details, { chicken_id: '', eggs: '' }] })}>
                  + Tambah ayam
                </Btn>
              </div>
            </div>

            <Field label="Catatan (opsional)">
              <input value={form.notes}
                onChange={(e) => setForm({ ...form, notes: e.target.value })} className={inputCls} />
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
