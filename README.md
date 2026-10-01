# Egg Production App

Aplikasi Flutter untuk pencatatan produksi telur ayam dengan backend Python FastAPI.

## Fitur

- **Pencatatan Produksi Telur**: Catat produksi telur harian (total, baik, rusak, berat rata-rata)
- **Manajemen Ayam**: Kelola data ayam (total, sehat, sakit, mati, baru)
- **Pencatatan Pakan**: Catat konsumsi pakan dan biaya
- **Pencatatan Biaya**: Catat biaya operasional lainnya
- **Statistik & Laporan**: Visualisasi data produksi, ayam, dan biaya
- **Multi-User**: Role Admin dan Pegawai
- **Mode Offline**: Data tersimpan lokal saat offline, sync saat online
- **Notifikasi**: Pengingat harian untuk pencatatan

## Struktur Project

```
egg-production-app/
├── backend/                 # Python FastAPI Backend
│   ├── app/
│   │   ├── routers/        # API endpoints
│   │   ├── models.py       # Database models
│   │   ├── schemas.py      # Pydantic schemas
│   │   ├── auth.py         # Authentication
│   │   ├── database.py     # Database connection
│   │   ├── config.py       # Configuration
│   │   └── main.py         # Entry point
│   ├── Dockerfile
│   ├── docker-compose.yml
│   └── requirements.txt
│
└── frontend/               # Flutter Frontend
    ├── lib/
    │   ├── models/         # Data models
    │   ├── services/       # API & local storage services
    │   ├── providers/      # State management
    │   ├── screens/        # UI screens
    │   ├── widgets/        # Reusable widgets
    │   └── utils/          # Utilities
    ├── pubspec.yaml
    └── main.dart
```

## Setup Backend

### Prerequisites
- Python 3.11+
- Docker & Docker Compose
- PostgreSQL (atau gunakan Docker)

### Local Development

1. Clone repository
2. Buat virtual environment:
   ```bash
   cd backend
   python -m venv venv
   source venv/bin/activate  # Linux/Mac
   venv\Scripts\activate     # Windows
   ```

3. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

4. Copy `.env.example` ke `.env` dan sesuaikan:
   ```bash
   cp .env.example .env
   ```

5. Jalankan aplikasi:
   ```bash
   uvicorn app.main:app --reload
   ```

6. API documentation: `http://localhost:8000/docs`

### Docker Deployment

1. Build dan jalankan:
   ```bash
   docker-compose up -d
   ```

2. API akan berjalan di `http://localhost:8000`

## Setup Frontend

### Prerequisites
- Flutter SDK 3.0+
- Android Studio / VS Code

### Configuration

1. Update `lib/services/api_service.dart`:
   ```dart
   static const String baseUrl = 'http://YOUR_VPS_IP:8000/api';
   ```

2. Install dependencies:
   ```bash
   cd frontend
   flutter pub get
   ```

3. Jalankan aplikasi:
   ```bash
   flutter run
   ```

## Panduan Deploy ke VPS

### 1. Setup Database

```bash
# Pull dan jalankan PostgreSQL container
docker run -d \
  --name egg_postgres \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=your_secure_password \
  -e POSTGRES_DB=egg_production \
  -p 5432:5432 \
  -v postgres_data:/var/lib/postgresql/data \
  postgres:15
```

### 2. Setup Backend

```bash
# Clone project ke VPS
git clone <your-repo> /opt/egg-production
cd /opt/egg-production/backend

# Buat .env file
cat > .env << EOF
DATABASE_URL=postgresql://postgres:your_secure_password@localhost:5432/egg_production
SECRET_KEY=$(openssl rand -hex 32)
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=1440
DEBUG=False
EOF

# Build dan jalankan
docker-compose up -d
```

### 3. Setup Nginx Reverse Proxy

```bash
# Install Nginx
sudo apt update
sudo apt install nginx

# Buat konfigurasi
sudo nano /etc/nginx/sites-available/egg-production
```

```nginx
server {
    listen 80;
    server_name your-domain.com;

    location / {
        proxy_pass http://localhost:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

```bash
# Enable site
sudo ln -s /etc/nginx/sites-available/egg-production /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

### 4. Setup SSL dengan Let's Encrypt

```bash
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d your-domain.com
```

### 5. Update Flutter API URL

Update `frontend/lib/services/api_service.dart`:
```dart
static const String baseUrl = 'https://your-domain.com/api';
```

## API Endpoints

| Method | Endpoint | Deskripsi |
|--------|----------|-----------|
| POST | `/api/auth/register` | Register user baru |
| POST | `/api/auth/login` | Login |
| GET | `/api/auth/me` | Get current user info |
| GET | `/api/egg-productions/` | List produksi telur |
| POST | `/api/egg-productions/` | Tambah produksi telur |
| GET | `/api/chicken-managements/` | List manajemen ayam |
| POST | `/api/chicken-managements/` | Tambah manajemen ayam |
| GET | `/api/feed-records/` | List pakan |
| POST | `/api/feed-records/` | Tambah pakan |
| GET | `/api/cost-records/` | List biaya |
| POST | `/api/cost-records/` | Tambah biaya |
| GET | `/api/statistics/daily` | Statistik harian |
| GET | `/api/statistics/monthly` | Statistik bulanan |
| GET | `/api/users/` | List users (admin only) |

## License

MIT License
