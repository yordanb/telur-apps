from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from sqlalchemy import text
import os
from app.config import get_settings
from app.database import engine, Base
from app.routers import auth, egg_production, chicken_management, feed_records, cost_records, egg_sales, cash_transactions, chickens, statistics, user_management

settings = get_settings()


def _migrate_user_role_enum():
    """PostgreSQL: tambahkan nilai enum 'investor' ke tipe userrole jika belum ada.

    Tabel/users yang sudah ada tidak diubah oleh create_all, sehingga nilai enum
    baru harus ditambahkan secara manual. Dijalankan dengan autocommit karena
    ALTER TYPE ... ADD VALUE tidak boleh berada dalam transaksi (PG < 12).
    """
    try:
        with engine.connect() as conn:
            conn = conn.execution_options(isolation_level="AUTOCOMMIT")
            conn.execute(text("ALTER TYPE userrole ADD VALUE IF NOT EXISTS 'investor'"))
    except Exception:
        # Tipe enum belum ada (database baru) — akan dibuat lengkap oleh create_all
        pass


# Migrasi enum sebelum create_all
_migrate_user_role_enum()


def _ensure_cost_subcategory_column():
    """Tambahkan kolom cost_records.subcategory jika belum ada.

    create_all tidak menambah kolom ke tabel yang sudah ada, jadi kolom
    baru dipastikan manual. Idempoten (IF NOT EXISTS).
    """
    try:
        with engine.connect() as conn:
            conn = conn.execution_options(isolation_level="AUTOCOMMIT")
            conn.execute(text(
                "ALTER TABLE cost_records "
                "ADD COLUMN IF NOT EXISTS subcategory VARCHAR(100)"
            ))
    except Exception:
        # Tabel belum ada — akan dibuat lengkap oleh create_all
        pass


_ensure_cost_subcategory_column()

# Create database tables
Base.metadata.create_all(bind=engine)

app = FastAPI(
    title=settings.APP_NAME,
    description="API untuk pencatatan produksi telur ayam",
    version="1.0.0"
)

# Foto ayam: disajikan dari direktori uploads (volume persisten).
UPLOAD_DIR = os.environ.get("UPLOAD_DIR", "/app/uploads")
os.makedirs(UPLOAD_DIR, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=UPLOAD_DIR), name="uploads")

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify your domain
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(auth.router)
app.include_router(egg_production.router)
app.include_router(chicken_management.router)
app.include_router(feed_records.router)
app.include_router(cost_records.router)
app.include_router(egg_sales.router)
app.include_router(cash_transactions.router)
app.include_router(chickens.router)
app.include_router(statistics.router)
app.include_router(user_management.router)


@app.get("/")
def root():
    return {
        "message": "Welcome to Egg Production API",
        "version": "1.0.0",
        "docs": "/docs"
    }


@app.get("/health")
def health_check():
    return {"status": "healthy"}
