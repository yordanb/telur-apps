import { useState } from 'react';
import { useAuth } from '../lib/auth';
import { USER_ROLES, createOne, deleteOne, isAdmin, updateOne } from '../lib/crud';
import type { User } from '../lib/api';
import { useList } from '../hooks/useList';
import { Btn, ErrorBox, Field, Modal, PageHead, Pager, inputCls } from '../components/ui';

const emptyCreate = () => ({
  username: '', email: '', full_name: '', password: '', role: 'pegawai',
});

export default function Pengguna() {
  const { user } = useAuth();
  const { rows, loading, loadingMore, error, hasMore, reload, loadMore } =
    useList<User>('/users/', {});

  const [showCreate, setShowCreate] = useState(false);
  const [create, setCreate] = useState(emptyCreate());
  const [createErr, setCreateErr] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  const [editing, setEditing] = useState<User | null>(null);
  const [editRole, setEditRole] = useState('pegawai');
  const [editName, setEditName] = useState('');
  const [editEmail, setEditEmail] = useState('');
  const [editErr, setEditErr] = useState<string | null>(null);

  if (!isAdmin(user)) {
    return (
      <div className="rounded-2xl bg-white p-8 text-center shadow">
        <p className="text-lg font-semibold">🔒 Khusus admin</p>
        <p className="mt-1 text-sm text-gray-500">Manajemen pengguna hanya untuk role admin.</p>
      </div>
    );
  }

  function openEdit(u: User) {
    setEditing(u);
    setEditRole(u.role);
    setEditName(u.full_name ?? '');
    setEditEmail(u.email);
    setEditErr(null);
  }

  async function onCreate() {
    setSaving(true);
    setCreateErr(null);
    try {
      await createOne('/users/', {
        username: create.username.trim(),
        email: create.email.trim(),
        full_name: create.full_name.trim(),
        password: create.password,
        role: create.role,
      });
      setShowCreate(false);
      setCreate(emptyCreate());
      await reload();
    } catch (e) {
      setCreateErr(e instanceof Error ? e.message : 'Gagal membuat pengguna');
    } finally {
      setSaving(false);
    }
  }

  async function onEditSave() {
    if (!editing) return;
    setEditErr(null);
    try {
      await updateOne(`/users/${editing.id}`, {
        email: editEmail.trim(),
        full_name: editName.trim(),
        role: editRole,
      });
      setEditing(null);
      await reload();
    } catch (e) {
      setEditErr(e instanceof Error ? e.message : 'Gagal menyimpan');
    }
  }

  async function onDelete(u: User) {
    if (u.id === user?.id) {
      alert('Tidak bisa menghapus akun sendiri');
      return;
    }
    if (!window.confirm(`Hapus pengguna ${u.username}?`)) return;
    try {
      await deleteOne(`/users/${u.id}`);
      await reload();
    } catch (e) {
      alert(e instanceof Error ? e.message : 'Gagal menghapus');
    }
  }

  return (
    <div className="space-y-4">
      <PageHead
        title="👥 Manajemen Pengguna"
        action={<Btn kind="primary" onClick={() => { setCreate(emptyCreate()); setCreateErr(null); setShowCreate(true); }}>+ Tambah</Btn>}
      />
      <ErrorBox msg={error} />
      {loading ? (
        <p className="py-6 text-center text-gray-500">Memuat…</p>
      ) : (
        <div className="overflow-x-auto rounded-2xl bg-white shadow">
          <table className="w-full min-w-[560px] text-sm">
            <thead>
              <tr className="bg-gray-50 text-left text-xs text-gray-500">
                <th className="px-4 py-2">Username</th>
                <th className="px-4 py-2">Nama</th>
                <th className="px-4 py-2">Role</th>
                <th className="px-4 py-2 text-right">Aksi</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((u) => (
                <tr key={u.id} className="border-t">
                  <td className="px-4 py-2 font-medium">
                    {u.username}
                    {u.id === user?.id && <span className="ml-1 text-xs text-gray-400">(saya)</span>}
                  </td>
                  <td className="px-4 py-2">{u.full_name}</td>
                  <td className="px-4 py-2">
                    <span className="rounded-full bg-brand-100 px-2 py-0.5 text-xs font-semibold text-brand-800">
                      {u.role}
                    </span>
                  </td>
                  <td className="px-4 py-2 text-right">
                    <div className="flex justify-end gap-2">
                      <Btn onClick={() => openEdit(u)}>Ubah</Btn>
                      <Btn kind="danger" disabled={u.id === user?.id} onClick={() => void onDelete(u)}>Hapus</Btn>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          <Pager count={rows.length} hasMore={hasMore} loadingMore={loadingMore} onMore={loadMore} />
        </div>
      )}

      {showCreate && (
        <Modal title="Tambah pengguna" onClose={() => setShowCreate(false)}>
          <div className="space-y-3">
            <ErrorBox msg={createErr} />
            <Field label="Username">
              <input value={create.username} onChange={(e) => setCreate({ ...create, username: e.target.value })} className={inputCls} />
            </Field>
            <Field label="Email">
              <input type="email" value={create.email} onChange={(e) => setCreate({ ...create, email: e.target.value })} className={inputCls} />
            </Field>
            <Field label="Nama lengkap">
              <input value={create.full_name} onChange={(e) => setCreate({ ...create, full_name: e.target.value })} className={inputCls} />
            </Field>
            <Field label="Password">
              <input type="password" value={create.password} onChange={(e) => setCreate({ ...create, password: e.target.value })} className={inputCls} />
            </Field>
            <Field label="Role">
              <select value={create.role} onChange={(e) => setCreate({ ...create, role: e.target.value })} className={inputCls}>
                {USER_ROLES.map((r) => <option key={r} value={r}>{r}</option>)}
              </select>
            </Field>
            <Btn kind="primary" className="w-full" disabled={saving} onClick={() => void onCreate()}>
              {saving ? 'Menyimpan…' : 'Buat pengguna'}
            </Btn>
          </div>
        </Modal>
      )}

      {editing && (
        <Modal title={`Ubah ${editing.username}`} onClose={() => setEditing(null)}>
          <div className="space-y-3">
            <ErrorBox msg={editErr} />
            <Field label="Email">
              <input type="email" value={editEmail} onChange={(e) => setEditEmail(e.target.value)} className={inputCls} />
            </Field>
            <Field label="Nama lengkap">
              <input value={editName} onChange={(e) => setEditName(e.target.value)} className={inputCls} />
            </Field>
            <Field label="Role">
              <select value={editRole} onChange={(e) => setEditRole(e.target.value)} className={inputCls}>
                {USER_ROLES.map((r) => <option key={r} value={r}>{r}</option>)}
              </select>
            </Field>
            <Btn kind="primary" className="w-full" onClick={() => void onEditSave()}>Simpan</Btn>
          </div>
        </Modal>
      )}
    </div>
  );
}
