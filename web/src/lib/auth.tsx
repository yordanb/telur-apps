import { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react';
import type { ReactNode } from 'react';
import { fetchMe, getToken, login as apiLogin, logout as apiLogout } from './api';
import type { User } from './api';

interface AuthState {
  user: User | null;
  loading: boolean;
  error: string | null;
  login: (username: string, password: string) => Promise<void>;
  logout: () => void;
  refresh: () => Promise<void>;
}

const AuthContext = createContext<AuthState | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const refresh = useCallback(async () => {
    if (!getToken()) {
      setUser(null);
      setLoading(false);
      return;
    }
    setLoading(true);
    try {
      const me = await fetchMe();
      setUser(me);
      setError(null);
    } catch (e) {
      setUser(null);
      setError(e instanceof Error ? e.message : 'Gagal memuat sesi');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void refresh();
  }, [refresh]);

  const login = useCallback(async (username: string, password: string) => {
    setError(null);
    try {
      await apiLogin(username, password);
      const me = await fetchMe();
      setUser(me);
    } catch (e) {
      apiLogout();
      setUser(null);
      const msg = e instanceof Error ? e.message : 'Login gagal';
      setError(msg);
      throw new Error(msg);
    }
  }, []);

  const logout = useCallback(() => {
    apiLogout();
    setUser(null);
  }, []);

  const value = useMemo(
    () => ({ user, loading, error, login, logout, refresh }),
    [user, loading, error, login, logout, refresh],
  );
  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth(): AuthState {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth harus dipakai di dalam AuthProvider');
  return ctx;
}
