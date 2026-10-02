from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import text
from app.config import get_settings
from app.database import engine, Base
from app.routers import auth, egg_production, chicken_management, feed_records, cost_records, egg_sales, statistics, user_management

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

# Create database tables
Base.metadata.create_all(bind=engine)

app = FastAPI(
    title=settings.APP_NAME,
    description="API untuk pencatatan produksi telur ayam",
    version="1.0.0"
)

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
