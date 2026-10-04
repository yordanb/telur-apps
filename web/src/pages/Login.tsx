import { useState } from 'react';
import type { FormEvent } from 'react';
import { Navigate, useNavigate } from 'react-router-dom';
import { useAuth } from '../lib/auth';

const ROLE_LABEL: Record<string, string> = {
  admin: 'Admin',
  pegawai: 'Pegawai',
  investor: 'Investor',
};

export default function Login() {
  const { user, loading, login } = useAuth();
  const navigate = useNavigate();
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  if (!loading && user) return <Navigate to="/" replace />;

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    setError(null);
    setSubmitting(true);
    try {
      await login(username.trim(), password);
      navigate('/', { replace: true });
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Login gagal');
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <div className="flex min-h-screen items-center justify-center bg-gray-100 px-4">
      <div className="w-full max-w-md overflow-hidden rounded-2xl bg-white shadow-xl">
        <div className="bg-brand-600 px-8 py-6">
          <h1 className="text-2xl font-bold text-white">🥚 Endog</h1>
          <p className="mt-1 text-sm text-brand-100">Dashboard peternakan ayam — silakan masuk</p>
        </div>
        <form onSubmit={onSubmit} className="space-y-4 px-8 py-6">
          {error && (
            <div className="rounded-lg bg-red-50 px-4 py-3 text-sm text-red-700">{error}</div>
          )}
          <div>
            <label htmlFor="username" className="mb-1 block text-sm font-medium text-gray-700">
              Username
            </label>
            <input
              id="username"
              autoComplete="username"
              value={username}
              onChange={(e) => setUsername(e.target.value)}
              required
              className="w-full rounded-lg border border-gray-300 px-3 py-2 outline-none focus:border-brand-500 focus:ring-2 focus:ring-brand-200"
              placeholder="cth: admin"
            />
          </div>
          <div>
            <label htmlFor="password" className="mb-1 block text-sm font-medium text-gray-700">
              Password
            </label>
            <input
              id="password"
              type="password"
              autoComplete="current-password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
              className="w-full rounded-lg border border-gray-300 px-3 py-2 outline-none focus:border-brand-500 focus:ring-2 focus:ring-brand-200"
              placeholder="••••••••"
            />
          </div>
          <button
            type="submit"
            disabled={submitting}
            className="w-full rounded-lg bg-brand-600 px-4 py-2.5 font-semibold text-white transition hover:bg-brand-700 disabled:opacity-60"
          >
            {submitting ? 'Masuk…' : 'Masuk'}
          </button>
          <p className="text-center text-xs text-gray-500">
            JWT disimpan lokal · kedaluwarsa 1440 mnt ·{' '}
            {user ? ROLE_LABEL[user.role] ?? user.role : 'admin / pegawai / investor'}
          </p>
        </form>
      </div>
    </div>
  );
}
