// Konfigurasi API — sumber: VITE_API_URL (lihat web/.env.example).
// Default produksi: https://egg.mibt.my.id/api (kontrak: docs/HANDOFF-WEB.md §2)
export const API_URL =
  import.meta.env.VITE_API_URL?.replace(/\/$/, '') || 'https://egg.mibt.my.id/api';

export interface User {
  id: number;
  username: string;
  email: string;
  full_name?: string | null;
  role: 'admin' | 'pegawai' | 'investor';
  is_active: boolean;
}

const TOKEN_KEY = 'endog_token';

export function getToken(): string | null {
  return localStorage.getItem(TOKEN_KEY);
}

export function setToken(token: string) {
  localStorage.setItem(TOKEN_KEY, token);
}

export function clearToken() {
  localStorage.removeItem(TOKEN_KEY);
}

function authHeaders(): HeadersInit {
  const token = getToken();
  return token ? { Authorization: `Bearer ${token}` } : {};
}

/** POST /api/auth/login — body form-urlencoded (OAuth2PasswordRequestForm). */
export async function login(username: string, password: string): Promise<string> {
  const res = await fetch(`${API_URL}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ username, password }),
  });
  if (!res.ok) {
    if (res.status === 401) throw new Error('Username atau password salah');
    throw new Error(`Login gagal (${res.status})`);
  }
  const data = await res.json();
  if (!data.access_token) throw new Error('Respons login tidak valid');
  setToken(data.access_token);
  return data.access_token as string;
}

/** GET /api/auth/me */
export async function fetchMe(): Promise<User> {
  const res = await fetch(`${API_URL}/auth/me`, { headers: authHeaders() });
  if (res.status === 401) {
    clearToken();
    throw new Error('Sesi berakhir, silakan login kembali');
  }
  if (!res.ok) throw new Error(`Gagal memuat profil (${res.status})`);
  return (await res.json()) as User;
}

export function logout() {
  clearToken();
}
