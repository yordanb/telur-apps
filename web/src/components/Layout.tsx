import type { ReactNode } from 'react';
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

  return (
    <div className="flex min-h-screen bg-gray-100">
      {/* Sidebar ala TailAdmin, aksen oranye Endog */}
      <aside className="hidden w-60 shrink-0 flex-col bg-gray-900 text-gray-200 md:flex">
        <div className="px-5 py-5 text-xl font-bold text-white">
          🥚 Endog
        </div>
        <nav className="flex-1 space-y-1 px-3">
          {items.map((n) => (
            <NavLink
              key={n.to}
              to={n.to}
              className={({ isActive }) =>
                `flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium transition ${
                  isActive
                    ? 'bg-brand-600 text-white'
                    : 'text-gray-300 hover:bg-gray-800 hover:text-white'
                }`
              }
            >
              <span>{n.icon}</span>
              {n.label}
            </NavLink>
          ))}
        </nav>
        <div className="border-t border-gray-800 p-4 text-xs text-gray-400">
          {user?.username} · {user?.role}
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
