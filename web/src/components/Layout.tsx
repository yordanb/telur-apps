import type { ReactNode } from 'react';
import { useState } from 'react';
import { NavLink, useNavigate } from 'react-router-dom';
import { useAuth } from '../lib/auth';

interface NavItem {
  to: string;
  label: string;
  icon: string;
  adminOnly?: boolean;
}

// Menu meniru bottom-nav mobile (Beranda·Produksi·Data·Statistik·Pengaturan)
// diperluas per modul backend. Investor read-only ditegakkan server (403).
const NAV: NavItem[] = [
  { to: '/', label: 'Dashboard', icon: '🏠' },
  { to: '/statistik', label: 'Statistik', icon: '📊' },
  { to: '/produksi', label: 'Produksi', icon: '🥚' },
  { to: '/ayam', label: 'Ayam', icon: '🐔' },
  { to: '/pakan', label: 'Pakan', icon: '🌾' },
  { to: '/biaya', label: 'Biaya', icon: '🧾' },
  { to: '/penjualan', label: 'Penjualan', icon: '💰' },
  { to: '/kas', label: 'Kas', icon: '👛' },
  { to: '/keuangan', label: 'Keuangan', icon: '💳' },
  { to: '/produktivitas', label: 'Produktivitas', icon: '🏆' },
  { to: '/pengguna', label: 'Pengguna', icon: '👥', adminOnly: true },
  { to: '/log', label: 'Log Aktivitas', icon: '📋', adminOnly: true },
  { to: '/bantuan', label: 'Bantuan', icon: '📖' },
  { to: '/pengaturan', label: 'Pengaturan', icon: '⚙️' },
];

export default function Layout({ children }: { children: ReactNode }) {
  const { user, logout } = useAuth();
  const navigate = useNavigate();

  function onLogout() {
    logout();
    navigate('/login', { replace: true });
  }

  const items = NAV.filter((n) => !n.adminOnly || user?.role === 'admin');
  // Mode mini (ikon saja) tersimpan per browser.
  const [mini, setMini] = useState(() => localStorage.getItem('endog_sidebar') === 'mini');

  function toggleMini() {
    setMini((m) => {
      localStorage.setItem('endog_sidebar', m ? 'open' : 'mini');
      return !m;
    });
  }

  return (
    <div className="flex min-h-screen bg-gray-100">
      {/* Sidebar ala TailAdmin, aksen Endog; bisa mini (ikon saja) */}
      <aside
        className={`hidden shrink-0 flex-col bg-gray-900 text-gray-200 transition-all md:flex ${
          mini ? 'w-16' : 'w-60'
        }`}
      >
        <div className={`flex items-center py-5 text-xl font-bold text-white ${mini ? 'flex-col gap-2' : 'justify-between px-5'}`}>
          <span title="Endog">{mini ? '🥚' : '🥚 Endog'}</span>
          <button
            onClick={toggleMini}
            title={mini ? 'Tampilkan menu' : 'Sembunyikan (ikon saja)'}
            className="rounded-lg px-2 py-1 text-sm text-gray-400 hover:bg-gray-800 hover:text-white"
          >
            {mini ? '▶' : '◀'}
          </button>
        </div>
        <nav className="flex-1 space-y-1 px-3">
          {items.map((n) => (
            <NavLink
              key={n.to}
              to={n.to}
              title={n.label}
              className={({ isActive }) =>
                `flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium transition ${
                  mini ? 'justify-center' : ''
                } ${
                  isActive
                    ? 'bg-brand-600 text-white'
                    : 'text-gray-300 hover:bg-gray-800 hover:text-white'
                }`
              }
            >
              <span>{n.icon}</span>
              {!mini && n.label}
            </NavLink>
          ))}
        </nav>
        <div className="border-t border-gray-800 p-4 text-gray-400">
          {mini ? (
            <button
              onClick={toggleMini}
              title={`Tampilkan menu (${user?.username})`}
              className="mx-auto flex h-9 w-9 items-center justify-center rounded-full bg-brand-600 text-sm font-bold text-white"
            >
              {user?.username?.[0]?.toUpperCase() ?? '?'}
            </button>
          ) : (
            <p className="text-xs">
              {user?.username} · {user?.role}
            </p>
          )}
        </div>
      </aside>

      <div className="flex min-w-0 flex-1 flex-col">
        <header className="sticky top-0 z-10 border-b bg-white">
          <div className="flex items-center justify-between px-4 py-3">
            <span className="font-bold text-brand-700 md:hidden">🥚 Endog</span>
            {/* Nav mobile: horizontal scroll */}
            <nav className="flex gap-1 overflow-x-auto md:hidden">
              {items.map((n) => (
                <NavLink
                  key={n.to}
                  to={n.to}
                  className={({ isActive }) =>
                    `whitespace-nowrap rounded-lg px-2.5 py-1.5 text-xs font-medium ${
                      isActive ? 'bg-brand-600 text-white' : 'text-gray-600 hover:bg-gray-100'
                    }`
                  }
                >
                  {n.icon} {n.label}
                </NavLink>
              ))}
            </nav>
            <div className="ml-auto flex items-center gap-3 text-sm">
              <span className="hidden text-gray-600 sm:inline">
                {user?.username} · <span className="font-semibold">{user?.role}</span>
              </span>
              <button
                onClick={onLogout}
                className="rounded-lg border border-gray-300 px-3 py-1.5 hover:bg-gray-50"
              >
                Keluar
              </button>
            </div>
          </div>
        </header>
        <main className="mx-auto w-full max-w-6xl flex-1 px-4 py-6">{children}</main>
      </div>
    </div>
  );
}
