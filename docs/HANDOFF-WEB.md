# HANDOFF — Web Dashboard (manajemen via website)

> Dokumen jembatan antar-tab/sesi OpenCode. Tab baru WAJIB baca file ini dulu
> sebelum coding. Setiap selesai milestone, update bagian "Status terakhir"
> lalu commit + push.

## 1. Gambaran proyek

Aplikasi pencatatan produksi telur ayam ("Endog"):
- **Backend**: FastAPI + PostgreSQL 15 (Docker) — `backend/`
- **Mobile**: Flutter Android (Riverpod + GoRouter) — `frontend/`
- **Web dashboard** (baru, dikerjakan di tab terpisah): diusulkan folder `web/`
  (stack belum diputuskan — tentukan di tab web, lalu tulis di sini).

Repo: `https://github.com/yordanb/telur-apps.git`, branch utama `master`.

## 2. Backend — kontrak API (sumber kebenaran)

Base URL produksi: `https://egg.mibt.my.id/api`
OpenAPI/Swagger: `https://egg.mibt.my.id/openapi.json` (selalu cek ini dulu —
skema di sini yang berlaku, bukan tebakan).

### Auth
- Login: `POST /api/auth/login` body **form-urlencoded**
  (`username=...&password=...`) → `{access_token, token_type}`
- Selanjutnya: header `Authorization: Bearer <token>` (JWT, expiry 1440 mnt)
- Profil: `GET /api/auth/me`; ubah profil: `PUT /api/auth/me`
  (hanya `email`/`full_name` — role tidak bisa diubah sendiri)
- Ganti password: `PUT /api/auth/change-password`
  `{old_password, new_password(min 6)}` → 400 jika password lama salah
- Register publik `POST /api/auth/register` hanya menghasilkan role
  **pegawai** (kecuali DB kosong → bootstrap admin). Jangan andalkan untuk
  membuat admin/investor — itu lewat Manajemen User.

### Role & permission matrix (ditegakkan server via guard)

| Guard | Arti |
|---|---|
| `require_editor` | Tolak investor (403). Dipakai SEMUA POST/PUT/DELETE/upload |
| `require_admin` | Hanya admin. Dipakai SEMUA endpoint `/api/users/*` |
| `can_view_all_data()` | True utk admin+investor (lihat semua), pegawai difilter `user_id` miliknya |

| Kemampuan | admin | pegawai | investor |
|---|---|---|---|
| Lihat semua data | ✅ | ❌ (milik sendiri) | ✅ |
| Tulis (7 modul data) | ✅ | ✅ milik sendiri | ❌ 403 |
| Statistik/Keuangan/Produktivitas | ✅ semua | ✅ sendiri | ✅ semua |
| Manajemen user | ✅ | ❌ | ❌ |

### Endpoint (prefix `/api`, pola CRUD identik: list ada filter tanggal + pagination `skip/limit`)

| Prefix | Modul | Aturan bisnis khusus |
|---|---|---|
| `/egg-productions/` | Produksi telur | `details[]` opsional `{chicken_id, eggs}`; jika diisi server **paksa** `total_eggs=good_eggs=sum(rincian)`. Response nested `details[]` (+`chicken_code/name`). Validasi: ayam harus terdaftar, 1 ayam 1× per catatan |
| `/chickens/` | Register ayam | **Aset kandang bersama**: list/detail terlihat semua role; tulis = pegawai+admin; hapus = pemilik/admin. `code` unik global. Status: aktif/sakit/mati/terjual |
| `/chickens/{id}/photo` | Upload foto (multipart `photo`, ≤5MB, jpg/png/webp) | Disajikan di `/uploads/<file>` (bukan di bawah `/api`!) |
| `/chicken-managements/` | Agregat ayam | Biasa, per-user |
| `/feedings/` | Pemberian pakan | Validasi **stok**: `quantity ≤ sisa` (400 jika over). `GET /feedings/stock` → `{jenis: sisa_kg}` **global**, boleh semua role login |
| `/cost-records/` | Biaya | Kategori: pakan/obat/operasional/lainnya. Jika `pakan`: wajib `feed_type`, `quantity_kg`, `price_per_kg`; `amount` = qty×harga. Jika operasional: `subcategory` (Perbaikan/Perawatan/Pembuatan kandang) |
| `/egg-sales/` | Penjualan | `unit` butir/kg; `total_price` **dihitung server** |
| `/cash-transactions/` | Kas manual | `direction` masuk/keluar; `amount` > 0 (server menolak ≤0) |
| `/statistics/daily` | Statistik harian | Berbasis tanggal produksi; ada `feed_cost` (dari Biaya-pakan), `other_cost`, `sales_revenue` |
| `/statistics/monthly` | Statistik bulanan | +`total_sales_revenue`, `total_other_income`, `total_other_expense` |
| `/users/` | Manajemen user | Admin only. Role: admin/pegawai/investor |

### Aturan domain penting (jangan dilanggar di web)
1. **Stok pakan** = pembelian (Biaya kategori pakan, per `feed_type`) − pemberian (`feedings`). Tabel lama `feed_records` **pensiun** (dikosongkan via migrasi, jangan dipakai lagi).
2. **Keuangan**: pemasukan = penjualan telur + kas masuk; pengeluaran = SEMUA Biaya + kas keluar. Catatan Pakan/feeding tidak menyentuh kas.
3. **Ayam bersama, uang per-user**: ayam & stok terlihat semua role; Biaya/kas difilter pemilik utk pegawai.
4. Foto: `photo_path` = `uploads/<file>` → URL penuh = `https://egg.mibt.my.id/uploads/<file>`.

## 3. Database

PostgreSQL 15. Tabel: `users`, `egg_productions`, `egg_production_details`,
`chickens`, `chicken_managements`, `feed_records` (pensiun/kosong),
`feedings`, `cost_records`, `egg_sales`, `cash_transactions`.
Enum: `userrole` (admin/pegawai/investor), `saleunit`, `cashdirection`.

Migrasi jalan otomatis saat container start (`backend/app/main.py`):
tambah enum investor, kolom `cost_records.subcategory`, kolom pakan di biaya,
pindah data `feed_records`→Biaya (sekali jalan, atomik). Tabel baru via
`create_all`. **Pola yang sama wajib dipakai utk perubahan skema baru**
(jangan ekspektasi migrasi otomatis selain itu — tidak ada Alembic aktif).

## 4. Infrastruktur & deploy (VPS)

- VPS path: `/opt/projects/telur-apps`, backend di `.../backend`
- Compose (`backend/docker-compose.yml`): `egg-api` (host 8800→8000),
  `egg-db` (host 5445→5432, PG15), `egg-backup` (pg_dump/6 jam + arsip
  foto harian → `backend/backups/`, retensi 14 hari)
- Volume: `postgres_data`, `uploads` (foto ayam)
- Domain `https://egg.mibt.my.id` via Cloudflare → Nginx → 8800.
  **Penting**: pastikan Nginx mem-proxy `location /uploads/` ke backend
  (sama seperti `/api`), kalau tidak foto 404.
- Deploy: `git pull && cd backend && docker compose up -d --build`
- **LARANGAN**: `down -v`, `volume prune`, `system prune --volumes`
  (pernah menghapus seluruh data produksi).

## 5. Aplikasi mobile (referensi perilaku)

Flutter + Riverpod + GoRouter, bottom nav 5: Beranda·Produksi·Data·Statistik·Pengaturan.
Pola offline-first: tulis gagal → antrean lokal (id sementara **negatif**,
chip "Offline") → auto-sync saat online/kembali (listener konektivitas +
setiap refresh) → cache respons terakhir untuk lihat offline.
Web **tidak wajib** meniru offline ini, tapi wajib meniru **matriks
permission & aturan domain §2**.

## 6. Rencana web dashboard (dikerjakan di tab baru)

Stack (diputuskan): **React + Vite + TypeScript + Tailwind**, basis tema
**TailAdmin** (aksen oranye Endog), folder `web/`.
Hak akses wajib meniru mobile: investor read-only, Manajemen User admin only.

### Docker (diputuskan — mengikuti pola backend)
- `web/Dockerfile` multi-stage: `node:20-alpine` build → `nginx:alpine`
  serve statis + `web/nginx.conf` (fallback SPA `try_files`).
- `web/docker-compose.yml` TERPISAH dari backend (lifecycle independen):
  container `endog-web`, publish host `8801:80`, `restart: unless-stopped`.
- Config build-time: `VITE_API_URL=https://egg.mibt.my.id/api`
  (via `web/.env`, contoh di `web/.env.example` — jangan commit `.env`).
- Routing satu domain (di `mibt-nginx`, dikelola manual di VPS):
  `/` → `127.0.0.1:8801` (web), `/api/`, `/docs`, `/openapi.json`,
  `/uploads/` → `127.0.0.1:8800` (egg-api). Lalu
  `docker exec mibt-nginx nginx -s reload`.
- Deploy web: `cd web && docker compose up -d --build` (tanpa `-v`,
  larangan §4 tetap berlaku).

## 7. Aturan kerja multi-tab (WAJIB)

1. Backend = kontrak bersama. Ubah API/skema/permission → update §2/§3
   file ini + umumkan di commit message.
2. Satu fitur satu branch jika paralel dengan mobile; merge via `master`.
3. Setiap perubahan backend diuji: `compileall` + **uji import/boot lokal**
   (pernah lolos bug NameError yang crash-kan produksi).
4. Verifikasi solusi via eksekusi (tes endpoint, bukan asumsi).
5. Jangan tebak URL/endpoint — cek `/openapi.json` atau baca router.

## 8. Status terakhir (update tiap milestone)

- `c9bd80f` (2026-10-04): Feed redesign — beli di Biaya + kg, Feeding +
  stok per jenis, migrasi otomatis pembelian lama. **Sudah deploy VPS.**
- Akun uji: `admin/admin123` (admin). Pegawai: `imam`. Investor: `goyu`, `rosi`.
- Data produksi = data dummy trial; rencana reset via TRUNCATE sebelum go-live
  (belum dieksekusi saat dokumen ini ditulis).
- Web dashboard: **scaffold + modul berjalan** (React 18 + Vite 5 + TS +
  Tailwind + react-router 6, basis TailAdmin; `web/` + Dockerfile multi-stage
  + compose terpisah `endog-web:8801` + nginx SPA fallback). Halaman:
  Login (JWT), Dashboard, Statistik, Produksi, Ayam (+foto), Pakan
  (pakai `/feedings/` + `/feedings/stock`), Biaya, Penjualan, Kas,
  Pengguna (admin), Pengaturan (profil + ganti password),
  Keuangan (neraca arus kas), Produktivitas (hen-day per ekor).
- Backend bertambah (oleh tab web): `PUT /api/auth/change-password`
  (`old_password`, `new_password` min 6; 400 jika salah/pendek).
- README.md repo diperbarui mengikuti implementasi (2026-10-04).
- Web scaffold `web/` (2026-10-04): Vite React-TS + Tailwind + React Router,
  halaman Login (JWT), Dockerfile multi-stage + nginx.conf + docker-compose
  terpisah (`endog-web` 8801:80). Sudah deploy VPS, Login jalan.
- Web milestone Dashboard+Statistik: sidebar TailAdmin-oranye + Dashboard
  ringkasan + halaman Statistik (filter tanggal + tahun). Sudah deploy, jalan.
- Web milestone modul data (2026-10-04): Produksi (+rincian/ayam),
  Ayam (register + foto + agregat), Pakan (stok global), Biaya (pakan/kg
  auto, subkategori operasional), Penjualan (total server), Kas (kategori
  per arah), Pengguna (admin only). Filter tanggal + "Muat lagi",
  investor read-only (tombol tulis disembunyikan).
- Web+API Pengaturan (2026-10-04): halaman Pengaturan (ubah nama/email +
  ganti password) + endpoint baru `PUT /api/auth/change-password`
  (verifikasi password lama, min 6). Diuji lokal: compileall + impor
  router + unit logika (400 salah/pendek, sukses+hash). Perlu deploy
  backend juga: `git pull && cd backend && docker compose up -d --build`.
