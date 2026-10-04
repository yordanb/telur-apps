import { Navigate, Route, Routes } from 'react-router-dom';
import type { ReactNode } from 'react';
import Layout from './components/Layout';
import { useAuth } from './lib/auth';
import Login from './pages/Login';
import Dashboard from './pages/Dashboard';
import Statistik from './pages/Statistik';
import Placeholder from './pages/Placeholder';

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
      <Layout>{el}</Layout>
    </RequireAuth>
  );
}

export default function App() {
  return (
    <Routes>
      <Route path="/login" element={<Login />} />
      <Route path="/" element={authed(<Dashboard />)} />
      <Route path="/statistik" element={authed(<Statistik />)} />
      <Route path="/produksi" element={authed(<Placeholder title="🥚 Produksi Telur" />)} />
      <Route path="/ayam" element={authed(<Placeholder title="🐔 Data Ayam" />)} />
      <Route path="/pakan" element={authed(<Placeholder title="🌾 Pemberian Pakan" />)} />
      <Route path="/biaya" element={authed(<Placeholder title="🧾 Biaya" />)} />
      <Route path="/penjualan" element={authed(<Placeholder title="💰 Penjualan Telur" />)} />
      <Route path="/kas" element={authed(<Placeholder title="👛 Kas Manual" />)} />
      <Route path="/pengguna" element={authed(<Placeholder title="👥 Manajemen Pengguna" />)} />
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}
