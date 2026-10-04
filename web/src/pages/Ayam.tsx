import { useState } from 'react';
import { useAuth } from '../lib/auth';
import {
  CHICKEN_STATUSES, canWrite, createOne, deleteOne, fileUrl,
  fromLocalInput, isAdmin, nowLocalInput, toLocalInput, updateOne, uploadPhoto,
} from '../lib/crud';
import { fmtDate, toISODate } from '../lib/api';
import { useList } from '../hooks/useList';
import { Btn, ErrorBox, Field, FilterBar, Modal, PageHead, Pager, inputCls } from '../components/ui';

interface Chicken {
  id: number;
  code: string;
  name?: string | null;
  breed?: string | null;
  acquired_date?: string | null;
  status: string;
  notes?: string | null;
  photo_path?: string | null;
  user_id: number;
}

interface Agregat {
  id: number;
  date: string;
  total_chickens: number;
  healthy_chickens: number;
  sick_chickens: number;
  dead_chickens: number;
  new_chickens: number;
  notes?: string | null;
}

const emptyChicken = () => ({
  code: '', name: '', breed: '', acquired_date: '', status: 'aktif', notes: '',
});

const emptyAgregat = () => ({
  date: nowLocalInput(), total_chickens: '', healthy_chickens: '',
  sick_chickens: '0', dead_chickens: '0', new_chickens: '0', notes: '',
});

export default function Ayam() {
  const { user } = useAuth();
  const writable = canWrite(user);
  const [tab, setTab] = useState<'register' | 'agregat'>('register');

  return (
    <div className="space-y-4">
      <PageHead title="🐔 Data Ayam" />
      <div className="flex gap-2">
        {(['register', 'agregat'] as const).map((t) => (
          <button
            key={t}
            onClick={() => setTab(t)}
            className={`rounded-lg px-4 py-2 text-sm font-medium ${
              tab === t ? 'bg-brand-600 text-white' : 'bg-white text-gray-600 shadow'
            }`}
          >
            {t === 'register' ? 'Register' : 'Agregat harian'}
          </button>
        ))}
      </div>
      {tab === 'register' ? <Register writable={writable} userId={user?.id} admin={isAdmin(user)} />
        : <AgregatTab writable={writable} />}
    </div>
  );
}

function Register({ writable, userId, admin }: { writable: boolean; userId?: number; admin: boolean }) {
  const [statusF, setStatusF] = useState('');
  const { rows, loading, loadingMore, error, hasMore, reload, loadMore } =
    useList<Chicken>('/chickens/', { status_filter: statusF || undefined }, 50);

  const [showForm, setShowForm] = useState(false);
  const [editing, setEditing] = useState<Chicken | null>(null);
  const [form, setForm] = useState(emptyChicken());
  const [formErr, setFormErr] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [photoErr, setPhotoErr] = useState<string | null>(null);
  const [uploadingId, setUploadingId] = useState<number | null>(null);
  const [brokenImg, setBrokenImg] = useState<Record<number, boolean>>({});

  function openCreate() {
    setEditing(null);
    setForm(emptyChicken());
    setFormErr(null);
    setShowForm(true);
  }

  function openEdit(c: Chicken) {
    setEditing(c);
    setForm({
      code: c.code, name: c.name ?? '', breed: c.breed ?? '',
      acquired_date: c.acquired_date ? toLocalInput(c.acquired_date).slice(0, 10) : '',
      status: c.status, notes: c.notes ?? '',
    });
    setFormErr(null);
    setShowForm(true);
  }

  async function onSave() {
    setFormErr(null);
    setSaving(true);
    try {
      const body = {
        code: form.code.trim(),
        name: form.name.trim() || null,
        breed: form.breed.trim() || null,
        acquired_date: form.acquired_date ? new Date(form.acquired_date).toISOString() : null,
        status: form.status,
        notes: form.notes.trim() || null,
      };
      if (editing) await updateOne(`/chickens/${editing.id}`, body);
      else await createOne('/chickens/', body);
      setShowForm(false);
      await reload();
    } catch (e) {
      setFormErr(e instanceof Error ? e.message : 'Gagal menyimpan');
    } finally {
      setSaving(false);
    }
  }

  async function onDelete(c: Chicken) {
    if (!window.confirm(`Hapus ayam ${c.code}?`)) return;
    try {
      await deleteOne(`/chickens/${c.id}`);
      await reload();
    } catch (e) {
      alert(e instanceof Error ? e.message : 'Gagal menghapus');
    }
  }

  async function onPhoto(c: Chicken, file: File | undefined) {
    if (!file || uploadingId != null) return;
    setPhotoErr(null);
    setUploadingId(c.id);
    try {
      await uploadPhoto(`/chickens/${c.id}/photo`, file);
      setBrokenImg((prev) => {
        const next = { ...prev };
        delete next[c.id];
        return next;
      });
      await reload();
    } catch (e) {
      setPhotoErr(e instanceof Error ? e.message : 'Gagal mengunggah foto');
    } finally {
      setUploadingId(null);
    }
  }

  return (
    <div className="space-y-4">
      <FilterBar>
        <Field label="Status">
          <select value={statusF} onChange={(e) => setStatusF(e.target.value)} className={inputCls}>
            <option value="">Semua</option>
            {CHICKEN_STATUSES.map((s) => <option key={s} value={s}>{s}</option>)}
          </select>
        </Field>
        {writable && <Btn kind="primary" onClick={openCreate}>+ Daftarkan ayam</Btn>}
      </FilterBar>

      <ErrorBox msg={error} />
      <ErrorBox msg={photoErr} onClose={() => setPhotoErr(null)} />
      {loading ? (
        <p className="py-6 text-center text-gray-500">Memuat…</p>
      ) : (
        <>
          <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
            {rows.map((c) => {
              const url = fileUrl(c.photo_path);
              const canDelete = admin || (userId != null && c.user_id === userId);
              return (
                <div key={c.id} className="overflow-hidden rounded-2xl bg-white shadow">
                  {url && !brokenImg[c.id] ? (
                    <img
                      src={url}
                      alt={c.code}
                      className="h-36 w-full object-cover"
                      loading="lazy"
                      onError={() => setBrokenImg((prev) => ({ ...prev, [c.id]: true }))}
                    />
                  ) : (
                    <div className="flex h-20 items-center justify-center bg-gray-100 text-3xl">
                      🐔
                      {url && brokenImg[c.id] && (
                        <span className="ml-2 text-xs text-red-500">gambar tidak bisa dimuat</span>
                      )}
                    </div>
                  )}
                  <div className="p-4">
                    <div className="flex items-center justify-between">
                      <p className="font-bold text-gray-900">{c.code}</p>
                      <span className={`rounded-full px-2 py-0.5 text-xs font-semibold ${
                        c.status === 'aktif' ? 'bg-green-100 text-green-700' : 'bg-gray-200 text-gray-600'
                      }`}>{c.status}</span>
                    </div>
                    {c.name && <p className="text-sm text-gray-600">{c.name}</p>}
                    {c.breed && <p className="text-xs text-gray-500">{c.breed}</p>}
                    {writable && (
                      <div className="mt-3 flex flex-wrap gap-2">
                        <Btn onClick={() => openEdit(c)}>Ubah</Btn>
                        <label className={`rounded-lg border border-gray-300 px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 ${uploadingId === c.id ? 'cursor-wait opacity-60' : 'cursor-pointer'}`}>
                          {uploadingId === c.id ? 'Mengunggah…' : 'Foto'}
                          <input type="file" accept=".jpg,.jpeg,.png,.webp" className="hidden"
                            disabled={uploadingId === c.id}
                            onChange={(e) => {
                              const f = e.target.files?.[0];
                              e.target.value = '';
                              void onPhoto(c, f);
                            }} />
                        </label>
                        {canDelete && <Btn kind="danger" onClick={() => void onDelete(c)}>Hapus</Btn>}
                      </div>
                    )}
                  </div>
                </div>
              );
            })}
          </div>
          <Pager count={rows.length} hasMore={hasMore} loadingMore={loadingMore} onMore={loadMore} />
        </>
      )}

      {showForm && (
        <Modal title={editing ? `Ubah ${editing.code}` : 'Daftarkan ayam'} onClose={() => setShowForm(false)}>
          <div className="space-y-3">
            <ErrorBox msg={formErr} />
            <Field label="Kode (unik)">
              <input value={form.code} onChange={(e) => setForm({ ...form, code: e.target.value })} className={inputCls} />
            </Field>
            <div className="grid grid-cols-2 gap-2">
              <Field label="Nama (opsional)">
                <input value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} className={inputCls} />
              </Field>
              <Field label="Jenis (opsional)">
                <input value={form.breed} onChange={(e) => setForm({ ...form, breed: e.target.value })} className={inputCls} />
              </Field>
            </div>
            <div className="grid grid-cols-2 gap-2">
              <Field label="Tanggal peroleh (opsional)">
                <input type="date" value={form.acquired_date}
                  onChange={(e) => setForm({ ...form, acquired_date: e.target.value })} className={inputCls} />
              </Field>
              <Field label="Status">
                <select value={form.status} onChange={(e) => setForm({ ...form, status: e.target.value })} className={inputCls}>
                  {CHICKEN_STATUSES.map((s) => <option key={s} value={s}>{s}</option>)}
                </select>
              </Field>
            </div>
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

function AgregatTab({ writable }: { writable: boolean }) {
  const today = new Date();
  const ago = new Date();
  ago.setDate(today.getDate() - 29);
  const [start, setStart] = useState(toISODate(ago));
  const [end, setEnd] = useState(toISODate(today));

  const { rows, loading, loadingMore, error, hasMore, reload, loadMore } =
    useList<Agregat>('/chicken-managements/', { start_date: start || undefined, end_date: end || undefined });

  const [showForm, setShowForm] = useState(false);
  const [editing, setEditing] = useState<Agregat | null>(null);
  const [form, setForm] = useState(emptyAgregat());
  const [formErr, setFormErr] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  function openCreate() {
    setEditing(null);
    setForm(emptyAgregat());
    setFormErr(null);
    setShowForm(true);
  }

  function openEdit(a: Agregat) {
    setEditing(a);
    setForm({
      date: toLocalInput(a.date),
      total_chickens: String(a.total_chickens),
      healthy_chickens: String(a.healthy_chickens),
      sick_chickens: String(a.sick_chickens),
      dead_chickens: String(a.dead_chickens),
      new_chickens: String(a.new_chickens),
      notes: a.notes ?? '',
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
        total_chickens: Number(form.total_chickens) || 0,
        healthy_chickens: Number(form.healthy_chickens) || 0,
        sick_chickens: Number(form.sick_chickens) || 0,
        dead_chickens: Number(form.dead_chickens) || 0,
        new_chickens: Number(form.new_chickens) || 0,
        notes: form.notes || null,
      };
      if (editing) await updateOne(`/chicken-managements/${editing.id}`, body);
      else await createOne('/chicken-managements/', body);
      setShowForm(false);
      await reload();
    } catch (e) {
      setFormErr(e instanceof Error ? e.message : 'Gagal menyimpan');
    } finally {
      setSaving(false);
    }
  }

  async function onDelete(a: Agregat) {
    if (!window.confirm(`Hapus agregat ${fmtDate(a.date)}?`)) return;
    try {
      await deleteOne(`/chicken-managements/${a.id}`);
      await reload();
    } catch (e) {
      alert(e instanceof Error ? e.message : 'Gagal menghapus');
    }
  }

  const num = (v: string, set: (s: string) => void) => ({
    value: v,
    onChange: (e: React.ChangeEvent<HTMLInputElement>) => set(e.target.value),
  });

  return (
    <div className="space-y-4">
      <FilterBar>
        <Field label="Dari">
          <input type="date" value={start} onChange={(e) => setStart(e.target.value)} className={inputCls} />
        </Field>
        <Field label="Sampai">
          <input type="date" value={end} onChange={(e) => setEnd(e.target.value)} className={inputCls} />
        </Field>
        {writable && <Btn kind="primary" onClick={openCreate}>+ Catat</Btn>}
      </FilterBar>

      <ErrorBox msg={error} />
      {loading ? (
        <p className="py-6 text-center text-gray-500">Memuat…</p>
      ) : (
        <div className="space-y-2">
          {rows.map((a) => (
            <div key={a.id} className="flex flex-wrap items-center justify-between gap-2 rounded-2xl bg-white p-4 shadow">
              <div>
                <p className="font-semibold">{fmtDate(a.date)}</p>
                <p className="text-sm text-gray-600">
                  Total <b>{a.total_chickens}</b> · Sehat {a.healthy_chickens} · Sakit {a.sick_chickens} ·
                  Mati {a.dead_chickens} · Baru {a.new_chickens}
                </p>
              </div>
              {writable && (
                <div className="flex gap-2">
                  <Btn onClick={() => openEdit(a)}>Ubah</Btn>
                  <Btn kind="danger" onClick={() => void onDelete(a)}>Hapus</Btn>
                </div>
              )}
            </div>
          ))}
          <Pager count={rows.length} hasMore={hasMore} loadingMore={loadingMore} onMore={loadMore} />
        </div>
      )}

      {showForm && (
        <Modal title={editing ? 'Ubah agregat' : 'Catat agregat'} onClose={() => setShowForm(false)}>
          <div className="space-y-3">
            <ErrorBox msg={formErr} />
            <Field label="Tanggal & jam">
              <input type="datetime-local" value={form.date}
                onChange={(e) => setForm({ ...form, date: e.target.value })} className={inputCls} />
            </Field>
            <div className="grid grid-cols-2 gap-2">
              <Field label="Total"><input type="number" min={0} {...num(form.total_chickens, (s) => setForm({ ...form, total_chickens: s }))} className={inputCls} /></Field>
              <Field label="Sehat"><input type="number" min={0} {...num(form.healthy_chickens, (s) => setForm({ ...form, healthy_chickens: s }))} className={inputCls} /></Field>
              <Field label="Sakit"><input type="number" min={0} {...num(form.sick_chickens, (s) => setForm({ ...form, sick_chickens: s }))} className={inputCls} /></Field>
              <Field label="Mati"><input type="number" min={0} {...num(form.dead_chickens, (s) => setForm({ ...form, dead_chickens: s }))} className={inputCls} /></Field>
            </div>
            <Field label="Ayam baru"><input type="number" min={0} {...num(form.new_chickens, (s) => setForm({ ...form, new_chickens: s }))} className={inputCls} /></Field>
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
