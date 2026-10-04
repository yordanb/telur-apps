import { Navigate, Route, Routes } from 'react-router-dom';
import { Suspense, lazy } from 'react';
import type { ReactNode } from 'react';
import Layout from './components/Layout';
import { useAuth } from './lib/auth';
import Login from './pages/Login';
import Produksi from './pages/Produksi';
import Ayam from './pages/Ayam';
import Pakan from './pages/Pakan';
import Biaya from './pages/Biaya';
import Penjualan from './pages/Penjualan';
import Kas from './pages/Kas';
import Pengguna from './pages/Pengguna';
import Pengaturan from './pages/Pengaturan';

// Halaman bergrafik dimuat malas agar bundle awal tetap kecil (recharts).
const Dashboard = lazy(() => import('./pages/Dashboard'));
const Statistik = lazy(() => import('./pages/Statistik'));
const Keuangan = lazy(() => import('./pages/Keuangan'));
const Produktivitas = lazy(() => import('./pages/Produktivitas'));

function RequireAuth({ children }: { children: ReactNode }) {
  const { user, loading } = useAuth();
  if (loading) {
    return <div className="flex min-h-screen items-center justify-center">Memuat…</div>;
  }
  if (!user) return <Navigate to="/login" replace />;
  return <>{children}</>;
}

function authed(el: ReactNode) {
  return (
    <RequireAuth>
      <Layout>
        <Suspense fallback={<div className="py-10 text-center text-gray-500">Memuat…</div>}>
          {el}
        </Suspense>
      </Layout>
    </RequireAuth>
  );
}

export default function App() {
  return (
    <Routes>
      <Route path="/login" element={<Login />} />
      <Route path="/" element={authed(<Dashboard />)} />
      <Route path="/statistik" element={authed(<Statistik />)} />
      <Route path="/produksi" element={authed(<Produksi />)} />
      <Route path="/ayam" element={authed(<Ayam />)} />
      <Route path="/pakan" element={authed(<Pakan />)} />
      <Route path="/biaya" element={authed(<Biaya />)} />
      <Route path="/penjualan" element={authed(<Penjualan />)} />
      <Route path="/kas" element={authed(<Kas />)} />
      <Route path="/keuangan" element={authed(<Keuangan />)} />
      <Route path="/produktivitas" element={authed(<Produktivitas />)} />
      <Route path="/pengguna" element={authed(<Pengguna />)} />
      <Route path="/pengaturan" element={authed(<Pengaturan />)} />
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}
