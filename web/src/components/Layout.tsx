import type { ReactNode } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useAuth } from '../lib/auth';

export default function Layout({ children }: { children: ReactNode }) {
  const { user, logout } = useAuth();
  const navigate = useNavigate();

  function onLogout() {
    logout();
    navigate('/login', { replace: true });
  }

  return (
    <div className="min-h-screen">
      <header className="border-b bg-white">
        <div className="mx-auto flex max-w-6xl items-center justify-between px-4 py-3">
          <Link to="/" className="text-lg font-bold text-brand-700">
            🥚 Endog
          </Link>
          {user && (
            <div className="flex items-center gap-3 text-sm">
              <span className="text-gray-600">
                {user.username} · <span className="font-semibold">{user.role}</span>
              </span>
              <button
                onClick={onLogout}
                className="rounded-lg border border-gray-300 px-3 py-1.5 hover:bg-gray-50"
              >
                Keluar
              </button>
            </div>
          )}
        </div>
      </header>
      <main className="bg-gray-50">{children}</main>
    </div>
  );
}
