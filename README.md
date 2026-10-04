# Endog — Pencatatan Produksi Telur Ayam

Aplikasi pencatatan produksi telur ayam: **backend FastAPI** + **aplikasi Android
(Flutter)** + **web dashboard manajemen (React)**.

## Fitur

- **Produksi Telur**: total harian + **rincian per ekor ayam** (ID ayam, jumlah butir)
- **Register Ayam**: identitas per ekor (kode unik, nama, jenis, status) + **foto profil**
- **Produktivitas Ayam**: telur/ekor/hari, laying rate %, peringkat teratas/terbawah
- **Pemberian Pakan (Feeding)**: catat pakan yang diberikan + **stok sisa per jenis pakan** (dibatasi stok, tidak bisa over)
- **Biaya**: pakan (otomatis tercatat saat beli, lengkap dengan kg & harga/kg), obat-obatan, operasional + subkategori kandang, lain-lain
- **Penjualan Telur**: per butir / per kg, total dihitung server
- **Keuangan (neraca)**: pemasukan vs pengeluaran, saldo, grafik arus kas, filter periode
- **Transaksi Kas**: pemasukan lain (ayam afkir, modal) & pengeluaran lain
- **Statistik**: grafik produksi, ayam, biaya, pendapatan
- **3 Role**: admin (semua + kelola user), pegawai (input & lihat milik sendiri), investor (lihat semua, read-only)
- **Mode Offline (Android)**: catat tanpa internet → antrean lokal → terkirim otomatis saat online
- **Profil & ganti password** langsung dari aplikasi/web
- **Notifikasi harian** (Android), pilihan 3 warna tema

## Struktur Project

```
.
├── backend/                 # FastAPI + PostgreSQL 15 (Docker)
│   ├── app/
│   │   ├── routers/        # auth, users, egg_production (+rincian),
│   │   │                   # chickens (+foto), chicken_management,
│   │   │                   # feedings (+stok), feed_records (pensiun),
│   │   │                   # cost_records, egg_sales, cash_transactions,
│   │   │                   # statistics
│   │   ├── models.py       # SQLAlchemy models
│   │   ├── schemas.py      # Pydantic schemas
│   │   ├── auth.py         # JWT guards (require_editor/require_admin)
│   │   └── main.py         # Entry point + migrasi startup + /uploads
│   ├── docker-compose.yml  # egg-api (8800), egg-db (5445), egg-backup
│   └── requirements.txt
├── frontend/               # Flutter Android (Riverpod + GoRouter)
│   └── lib/
│       ├── models/ providers/ screens/ services/ widgets/ utils/
├── web/                    # React + Vite + TS + Tailwind (TailAdmin)
│   ├── src/pages/          # Login, Dashboard, Statistik, Produksi, Ayam,
│   │                       # Pakan, Biaya, Penjualan, Kas, Pengguna, Pengaturan
│   ├── Dockerfile          # multi-stage node → nginx
│   ├── docker-compose.yml  # egg-web (8801), lifecycle terpisah
│   └── nginx.conf          # SPA fallback
└── docs/
    └── HANDOFF-WEB.md      # Konteks antar-sesi (wajib dibaca tab baru)
```

## Setup Backend (Docker, dipakai produksi)

```bash
cd backend
cp .env.example .env   # sesuaikan kredensial & SECRET_KEY
docker compose up -d --build
```

- API: `http://localhost:8800` → docs di `/docs`, skema di `/openapi.json`
- DB: `localhost:5445` (PostgreSQL 15)
- Backup otomatis tiap 6 jam → `backend/backups/` (dump DB + arsip foto)
- Migrasi skema jalan otomatis saat container start (lihat `app/main.py`)

> ⚠️ Jangan pernah `docker compose down -v` / `volume prune` di server —
> menghapus seluruh data.

## Deploy ke VPS

```bash
cd /opt/projects/telur-apps
git pull
cd backend && docker compose up -d --build     # tanpa -v
cd ../web && cp .env.example .env && docker compose up -d --build
```

Routing Nginx (`mibt-nginx`, `docker exec mibt-nginx nginx -s reload` sesudah edit):
`/`, → web (`127.0.0.1:8801`); `/api/`, `/docs`, `/openapi.json`, `/uploads/` → API (`127.0.0.1:8800`).
Domain produksi: `https://egg.mibt.my.id`.

## Setup Android

```bash
cd frontend
flutter pub get
flutter build apk --release
# hasil: build/app/outputs/flutter-apk/app-release.apk
```

Base URL API: `frontend/lib/services/api_service.dart` (`baseUrl`,
`serverRoot` untuk foto).

## Setup Web Dashboard

```bash
cd web
cp .env.example .env   # VITE_API_URL=https://egg.mibt.my.id/api (jangan commit .env)
npm install
npm run dev            # http://localhost:5173
```

Docker (terpisah dari backend):

```bash
cd web
docker compose up -d --build   # egg-web di 8801:80
```

Login memakai `POST {VITE_API_URL}/auth/login` (form-urlencoded), JWT di
`localStorage`, guard role meniru matriks di bawah.

## Role & Hak Akses

| Kemampuan | admin | pegawai | investor |
|---|---|---|---|
| Lihat semua data | ✅ | ❌ (milik sendiri) | ✅ |
| Input/edit/hapus data | ✅ | ✅ milik sendiri | ❌ read-only |
| Manajemen user | ✅ | ❌ | ❌ |

Pengecualian: register ayam & stok pakan terlihat semua role (aset kandang
bersama); hapus ayam hanya pemilik/admin.

## API Endpoints (ringkas)

| Method | Endpoint | Keterangan |
|---|---|---|
| POST | `/api/auth/login` | Login (form-urlencoded) → JWT |
| POST | `/api/auth/register` | Publik, selalu jadi pegawai (bootstrap admin jika DB kosong) |
| GET/PUT | `/api/auth/me` | Profil / update profil |
| PUT | `/api/auth/change-password` | Ganti password (`old_password`, `new_password` min 6) |
| POST | `/api/auth/logout` | Logout (catat aktivitas, token dibuang di klien) |
| GET | `/api/auth/client-ip` | IP klien (tanpa auth, untuk layar login) |
| GET | `/api/activity-logs/` | Log aktivitas (admin only, filter tanggal/aksi/user) |
| CRUD | `/api/egg-productions/` | + `details[]` per ayam; total dihitung server |
| CRUD | `/api/chickens/` | Register ayam; `POST /{id}/photo` upload foto |
| CRUD | `/api/feedings/` | Pemberian pakan (validasi stok); `GET /feedings/stock` sisa global |
| CRUD | `/api/cost-records/` | Biaya; kategori pakan wajib `feed_type`+kg+harga |
| CRUD | `/api/egg-sales/` | Penjualan; `total_price` dihitung server |
| CRUD | `/api/cash-transactions/` | Kas masuk/keluar manual |
| GET | `/api/statistics/daily`, `/monthly` | Agregat produksi, biaya, pendapatan, kas |
| CRUD | `/api/users/` | Admin only |
| GET | `/uploads/<file>` | File statis foto ayam |

Tabel `feed_records` sudah **dipensiunkan** (datanya dimigrasikan otomatis ke
Biaya-pakan saat start; jangan dipakai untuk fitur baru).

Skema lengkap selalu di `/openapi.json` — itu acuan yang berlaku.

## License

MIT License
