import { API_URL, clearToken, getToken } from './api';
import type { User } from './api';

// Pilihan nilai meniru mobile (frontend/lib/...):
// status ayam, kategori biaya, subkategori operasional, kategori kas.
export const CHICKEN_STATUSES = ['aktif', 'sakit', 'mati', 'terjual'];
export const COST_CATEGORIES = ['pakan', 'obat', 'operasional', 'lainnya'];
export const OP_SUBCATEGORIES = [
  'Perbaikan kandang',
  'Perawatan kandang',
  'Pembuatan kandang baru',
];
export const SALE_UNITS = ['butir', 'kg'];
export const CASH_DIRECTIONS = ['masuk', 'keluar'];
export const CASH_IN_CATS = ['Penjualan ayam afkir', 'Setoran modal', 'Lain-lain'];
export const CASH_OUT_CATS = ['Lain-lain'];
export const USER_ROLES = ['admin', 'pegawai', 'investor'];

export const canWrite = (u: User | null) => !!u && u.role !== 'investor';
export const isAdmin = (u: User | null) => !!u && u.role === 'admin';

/** URL penuh foto: photo_path = "uploads/<file>" disajikan di luar /api. */
export function fileUrl(photoPath: string | null | undefined): string | null {
  if (!photoPath) return null;
  if (photoPath.startsWith('http')) return photoPath;
  return `${API_URL.replace(/\/api$/, '')}/${photoPath.replace(/^\//, '')}`;
}

async function errMessage(res: Response): Promise<string> {
  try {
    const data = await res.json();
    const d = data?.detail;
    if (typeof d === 'string') return d;
    if (Array.isArray(d)) {
      return d.map((x) => x?.msg ?? JSON.stringify(x)).join('; ');
    }
  } catch {
    /* bukan JSON — pakai status */
  }
  return `Gagal (${res.status})`;
}

function authHeader(): HeadersInit {
  const token = getToken();
  return token ? { Authorization: `Bearer ${token}` } : {};
}

function checkAuth(res: Response) {
  if (res.status === 401) {
    clearToken();
    throw new Error('Sesi berakhir, silakan login kembali');
  }
}

async function parseBody<T>(res: Response): Promise<T> {
  const text = await res.text();
  if (!text) return undefined as T;
  return JSON.parse(text) as T;
}

/** GET objek tunggal (mis. /feedings/stock). */
export async function getOne<T>(path: string): Promise<T> {
  const res = await fetch(`${API_URL}${path}`, { headers: authHeader() });
  checkAuth(res);
  if (!res.ok) throw new Error(await errMessage(res));
  return parseBody<T>(res);
}

/** GET list ber-paginasi. pola: ?skip=&limit=&start_date=&end_date=[&filter] */
export async function list<T>(path: string): Promise<T[]> {
  const res = await fetch(`${API_URL}${path}`, { headers: authHeader() });
  checkAuth(res);
  if (!res.ok) throw new Error(await errMessage(res));
  return parseBody<T[]>(res);
}

export async function createOne<T>(path: string, body: unknown): Promise<T> {
  const res = await fetch(`${API_URL}${path}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', ...authHeader() },
    body: JSON.stringify(body),
  });
  checkAuth(res);
  if (!res.ok) throw new Error(await errMessage(res));
  return parseBody<T>(res);
}

export async function updateOne<T>(path: string, body: unknown): Promise<T> {
  const res = await fetch(`${API_URL}${path}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json', ...authHeader() },
    body: JSON.stringify(body),
  });
  checkAuth(res);
  if (!res.ok) throw new Error(await errMessage(res));
  return parseBody<T>(res);
}

export async function deleteOne(path: string): Promise<void> {
  const res = await fetch(`${API_URL}${path}`, { method: 'DELETE', headers: authHeader() });
  checkAuth(res);
  if (!res.ok) throw new Error(await errMessage(res));
  await parseBody<unknown>(res);
}

/** Upload foto ayam: POST multipart field `photo` (≤5MB, jpg/png/webp). */
export async function uploadPhoto<T>(path: string, file: File): Promise<T> {
  const form = new FormData();
  form.append('photo', file);
  const res = await fetch(`${API_URL}${path}`, {
    method: 'POST',
    headers: authHeader(),
    body: form,
  });
  checkAuth(res);
  if (!res.ok) throw new Error(await errMessage(res));
  return parseBody<T>(res);
}

/** Nilai untuk input datetime-local dari ISO backend. */
export function toLocalInput(iso: string | null | undefined): string {
  if (!iso) return '';
  const d = new Date(iso);
  const p = (n: number) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}T${p(d.getHours())}:${p(d.getMinutes())}`;
}

/** Nilai sekarang untuk input datetime-local. */
export function nowLocalInput(): string {
  return toLocalInput(new Date().toISOString());
}

/** datetime-local → ISO untuk backend. */
export function fromLocalInput(v: string): string {
  return new Date(v).toISOString();
}
