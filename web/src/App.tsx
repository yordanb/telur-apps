import { Navigate, Route, Routes } from 'react-router-dom';
import type { ReactNode } from 'react';
import Layout from './components/Layout';
import { useAuth } from './lib/auth';
import Login from './pages/Login';
import Dashboard from './pages/Dashboard';

function RequireAuth({ children }: { children: ReactNode }) {
  const { user, loading } = useAuth();
  if (loading) {
    return <div className="flex min-h-screen items-center justify-center">Memuat…</div>;
  }
  if (!user) return <Navigate to="/login" replace />;
  return <>{children}</>;
}

export default function App() {
  return (
    <Routes>
      <Route path="/login" element={<Login />} />
      <Route
        path="/"
        element={
          <RequireAuth>
            <Layout>
              <Dashboard />
            </Layout>
          </RequireAuth>
        }
      />
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}
