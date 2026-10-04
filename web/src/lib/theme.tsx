import { createContext, useCallback, useContext, useEffect, useState } from 'react';
import type { ReactNode } from 'react';
import { useAuth } from './auth';
import { updateMe } from './api';

// 3 pilihan tema, meniru Android (theme_color_provider.dart).
export type ThemeKey = 'oranye' | 'hijau' | 'biru';

export const THEMES: { key: ThemeKey; label: string; swatch: string }[] = [
  { key: 'oranye', label: 'Oranye', swatch: '#ea580c' },
  { key: 'hijau', label: 'Hijau', swatch: '#16a34a' },
  { key: 'biru', label: 'Biru', swatch: '#2563eb' },
];

const LS_KEY = 'endog_theme';

export function validTheme(v: unknown): v is ThemeKey {
  return v === 'oranye' || v === 'hijau' || v === 'biru';
}

interface ThemeState {
  theme: ThemeKey;
  setTheme: (t: ThemeKey) => Promise<void>;
}

const ThemeContext = createContext<ThemeState | null>(null);

export function ThemeProvider({ children }: { children: ReactNode }) {
  const { user, refresh } = useAuth();
  const [theme, setThemeState] = useState<ThemeKey>(() => {
    const ls = localStorage.getItem(LS_KEY);
    return validTheme(ls) ? ls : 'oranye';
  });

  // Profil server menang setelah login (tema ikut user pindah device).
  useEffect(() => {
    if (user && validTheme(user.theme_color)) {
      setThemeState(user.theme_color);
    }
  }, [user]);

  useEffect(() => {
    document.documentElement.dataset.theme = theme;
    localStorage.setItem(LS_KEY, theme);
  }, [theme]);

  const setTheme = useCallback(
    async (t: ThemeKey) => {
      setThemeState(t);
      try {
        await updateMe({ theme_color: t });
        await refresh();
      } catch (e) {
        // Optimistis: tema lokal tetap; error ditampilkan pemanggil.
        throw e;
      }
    },
    [refresh],
  );

  return <ThemeContext.Provider value={{ theme, setTheme }}>{children}</ThemeContext.Provider>;
}

export function useTheme(): ThemeState {
  const ctx = useContext(ThemeContext);
  if (!ctx) throw new Error('useTheme harus dipakai di dalam ThemeProvider');
  return ctx;
}
