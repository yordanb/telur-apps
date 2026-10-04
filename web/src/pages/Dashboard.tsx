import { useAuth } from '../lib/auth';

export default function Dashboard() {
  const { user, logout } = useAuth();
  return (
    <div className="mx-auto max-w-3xl px-4 py-10">
      <div className="rounded-2xl bg-white p-8 shadow">
        <h1 className="text-2xl font-bold text-gray-900">
          Halo, {user?.full_name || user?.username} 👋
        </h1>
        <p className="mt-2 text-sm text-gray-600">
          Role: <span className="font-semibold text-brand-700">{user?.role}</span> · Login JWT
          berhasil. Modul data (Produksi, Ayam, Biaya, dst.) menyusul di milestone berikutnya.
        </p>
        <button
          onClick={logout}
          className="mt-6 rounded-lg border border-gray-300 px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50"
        >
          Keluar
        </button>
      </div>
    </div>
  );
}
