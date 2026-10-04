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
  // Logout server best-effort agar tercatat di audit; token selalu dibuang.
  const token = getToken();
  if (token) {
    fetch(`${API_URL}/auth/logout`, { method: 'POST', headers: authHeaders() }).catch(() => {
      /* abaikan — offline/kedaluwarsa tetap logout lokal */
    });
  }
  clearToken();
}

/** PUT /api/auth/me — hanya email & nama (role tidak bisa diubah sendiri). */
export async function updateMe(data: { email?: string; full_name?: string }): Promise<User> {
  const res = await fetch(`${API_URL}/auth/me`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json', ...authHeaders() },
    body: JSON.stringify(data),
  });
  if (res.status === 401) {
    clearToken();
    throw new Error('Sesi berakhir, silakan login kembali');
  }
  if (!res.ok) {
    let msg = `Gagal menyimpan (${res.status})`;
    try {
      const d = (await res.json())?.detail;
      if (typeof d === 'string') msg = d;
    } catch { /* abaikan */ }
    throw new Error(msg);
  }
  return (await res.json()) as User;
}

/** PUT /api/auth/change-password */
export async function changePassword(old_password: string, new_password: string): Promise<void> {
  const res = await fetch(`${API_URL}/auth/change-password`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json', ...authHeaders() },
    body: JSON.stringify({ old_password, new_password }),
  });
  if (res.status === 401) {
    clearToken();
    throw new Error('Sesi berakhir, silakan login kembali');
  }
  if (!res.ok) {
    let msg = `Gagal (${res.status})`;
    try {
      const d = (await res.json())?.detail;
      if (typeof d === 'string') msg = d;
    } catch { /* abaikan */ }
    throw new Error(msg);
  }
}

// ---------- util ----------

export const fmtNum = (n: number) => new Intl.NumberFormat('id-ID').format(n);

export const fmtRp = (n: number) =>
  'Rp' + new Intl.NumberFormat('id-ID', { maximumFractionDigits: 0 }).format(n);

export const fmtDate = (iso: string) =>
  new Date(iso).toLocaleDateString('id-ID', { day: 'numeric', month: 'short', year: 'numeric' });

export const toISODate = (d: Date) =>
  `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;

async function authedGet<T>(path: string): Promise<T> {
  const res = await fetch(`${API_URL}${path}`, { headers: authHeaders() });
  if (res.status === 401) {
    clearToken();
    throw new Error('Sesi berakhir, silakan login kembali');
  }
  if (!res.ok) throw new Error(`Gagal memuat data (${res.status})`);
  return (await res.json()) as T;
}

// ---------- statistik (kontrak: backend/app/routers/statistics.py) ----------

export interface DailyStat {
  date: string;
  total_eggs: number;
  good_eggs: number;
  bad_eggs: number;
  total_chickens: number;
  healthy_chickens: number;
  feed_cost: number;
  other_cost: number;
  sales_revenue: number;
}

export interface MonthlyStat {
  year: number;
  month: number;
  total_eggs: number;
  good_eggs: number;
  bad_eggs: number;
  avg_daily_eggs: number;
  total_feed_cost: number;
  total_other_cost: number;
  total_sales_revenue: number;
  total_other_income: number;
  total_other_expense: number;
  total_chickens_end: number;
}

/** GET /api/statistics/daily?start_date=&end_date= */
export function getDailyStats(start_date?: string, end_date?: string): Promise<DailyStat[]> {
  const q = new URLSearchParams();
  if (start_date) q.set('start_date', start_date);
  if (end_date) q.set('end_date', end_date);
  const qs = q.toString();
  return authedGet<DailyStat[]>(`/statistics/daily${qs ? `?${qs}` : ''}`);
}

/** GET /api/statistics/monthly?year= */
export function getMonthlyStats(year?: number): Promise<MonthlyStat[]> {
  return authedGet<MonthlyStat[]>(`/statistics/monthly${year ? `?year=${year}` : ''}`);
}

export const MONTH_NAMES = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
];
