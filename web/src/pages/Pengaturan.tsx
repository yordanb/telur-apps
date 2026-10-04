import { useState } from 'react';
import { useAuth } from '../lib/auth';
import { changePassword, updateMe } from '../lib/api';
import { Btn, ErrorBox, Field, PageHead, inputCls } from '../components/ui';

export default function Pengaturan() {
  const { user, refresh } = useAuth();

  const [name, setName] = useState(user?.full_name ?? '');
  const [email, setEmail] = useState(user?.email ?? '');
  const [profileMsg, setProfileMsg] = useState<string | null>(null);
  const [profileErr, setProfileErr] = useState<string | null>(null);
  const [savingProfile, setSavingProfile] = useState(false);

  const [oldPw, setOldPw] = useState('');
  const [newPw, setNewPw] = useState('');
  const [confirmPw, setConfirmPw] = useState('');
  const [pwMsg, setPwMsg] = useState<string | null>(null);
  const [pwErr, setPwErr] = useState<string | null>(null);
  const [savingPw, setSavingPw] = useState(false);

  async function onSaveProfile() {
    setProfileErr(null);
    setProfileMsg(null);
    if (!name.trim()) {
      setProfileErr('Nama wajib diisi');
      return;
    }
    if (!email.includes('@')) {
      setProfileErr('Email tidak valid');
      return;
    }
    setSavingProfile(true);
    try {
      await updateMe({ full_name: name.trim(), email: email.trim() });
      await refresh();
      setProfileMsg('Profil tersimpan.');
    } catch (e) {
      setProfileErr(e instanceof Error ? e.message : 'Gagal menyimpan');
    } finally {
      setSavingProfile(false);
    }
  }

  async function onChangePassword() {
    setPwErr(null);
    setPwMsg(null);
    if (newPw !== confirmPw) {
      setPwErr('Konfirmasi password baru tidak sama');
      return;
    }
    if (newPw.length < 6) {
      setPwErr('Password baru minimal 6 karakter');
      return;
    }
    setSavingPw(true);
    try {
      await changePassword(oldPw, newPw);
      setOldPw('');
      setNewPw('');
      setConfirmPw('');
      setPwMsg('Password berhasil diubah.');
    } catch (e) {
      setPwErr(e instanceof Error ? e.message : 'Gagal mengubah password');
    } finally {
      setSavingPw(false);
    }
  }

  return (
    <div className="mx-auto max-w-2xl space-y-4">
      <PageHead title="⚙️ Pengaturan" />

      <div className="rounded-2xl bg-white p-5 shadow">
        <h2 className="font-semibold text-gray-900">Profil saya</h2>
        <p className="mt-1 text-sm text-gray-500">
          {user?.username} · <span className="font-semibold text-brand-700">{user?.role}</span>
          {' '}(username & role tidak bisa diubah sendiri)
        </p>
        <div className="mt-4 space-y-3">
          <ErrorBox msg={profileErr} />
          {profileMsg && <div className="rounded-xl bg-green-50 px-4 py-3 text-sm text-green-700">{profileMsg}</div>}
          <Field label="Nama lengkap">
            <input value={name} onChange={(e) => setName(e.target.value)} className={inputCls} />
          </Field>
          <Field label="Email">
            <input type="email" value={email} onChange={(e) => setEmail(e.target.value)} className={inputCls} />
          </Field>
          <Btn kind="primary" disabled={savingProfile} onClick={() => void onSaveProfile()}>
            {savingProfile ? 'Menyimpan…' : 'Simpan profil'}
          </Btn>
        </div>
      </div>

      <div className="rounded-2xl bg-white p-5 shadow">
        <h2 className="font-semibold text-gray-900">Ganti password</h2>
        <div className="mt-4 space-y-3">
          <ErrorBox msg={pwErr} />
          {pwMsg && <div className="rounded-xl bg-green-50 px-4 py-3 text-sm text-green-700">{pwMsg}</div>}
          <Field label="Password lama">
            <input type="password" autoComplete="current-password" value={oldPw}
              onChange={(e) => setOldPw(e.target.value)} className={inputCls} />
          </Field>
          <Field label="Password baru (min. 6 karakter)">
            <input type="password" autoComplete="new-password" value={newPw}
              onChange={(e) => setNewPw(e.target.value)} className={inputCls} />
          </Field>
          <Field label="Konfirmasi password baru">
            <input type="password" autoComplete="new-password" value={confirmPw}
              onChange={(e) => setConfirmPw(e.target.value)} className={inputCls} />
          </Field>
          <Btn kind="primary" disabled={savingPw} onClick={() => void onChangePassword()}>
            {savingPw ? 'Menyimpan…' : 'Ubah password'}
          </Btn>
        </div>
      </div>
    </div>
  );
}
