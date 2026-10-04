from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from sqlalchemy import text
from jose import jwt
import os
from app.config import get_settings
from app.database import engine, Base, SessionLocal
from app.activity import log_activity, client_ip, describe_write
from app.routers import auth, egg_production, chicken_management, feed_records, cost_records, egg_sales, cash_transactions, chickens, feedings, statistics, user_management, activity_logs

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


def _ensure_cost_feed_columns():
    """Kolom pembelian pakan di cost_records (feed_type/quantity_kg/price_per_kg)."""
    try:
        with engine.connect() as conn:
            conn = conn.execution_options(isolation_level="AUTOCOMMIT")
            for ddl in (
                "ALTER TABLE cost_records "
                "ADD COLUMN IF NOT EXISTS feed_type VARCHAR(100)",
                "ALTER TABLE cost_records "
                "ADD COLUMN IF NOT EXISTS quantity_kg DOUBLE PRECISION",
                "ALTER TABLE cost_records "
                "ADD COLUMN IF NOT EXISTS price_per_kg DOUBLE PRECISION",
            ):
                conn.execute(text(ddl))
    except Exception:
        pass


_ensure_cost_feed_columns()


def _migrate_feed_purchases_to_costs():
    """Sekali jalan: pindahkan pembelian pakan lama (feed_records) menjadi
    Biaya kategori pakan, lalu hapus baris asalnya agar tidak ganda.
    Atomik (satu transaksi); idempoten karena baris yang sudah pindah
    tidak ada lagi di tabel asal.
    """
    try:
        with engine.begin() as conn:
            exists = conn.execute(
                text("SELECT to_regclass('public.feed_records')")
            ).scalar()
            if not exists:
                return
            rows = conn.execute(
                text(
                    "SELECT id, user_id, date, feed_type, quantity_kg, "
                    "cost_per_kg, total_cost, notes, created_at "
                    "FROM feed_records"
                )
            ).mappings().all()
            for r in rows:
                conn.execute(
                    text(
                        "INSERT INTO cost_records "
                        "(user_id, date, category, description, amount, "
                        "feed_type, quantity_kg, price_per_kg, notes, created_at) "
                        "VALUES (:user_id, :date, 'pakan', :description, :amount, "
                        ":feed_type, :quantity_kg, :price_per_kg, :notes, :created_at)"
                    ),
                    {
                        "user_id": r["user_id"],
                        "date": r["date"],
                        "description": f"Pembelian {r['feed_type']}",
                        "amount": r["total_cost"],
                        "feed_type": r["feed_type"],
                        "quantity_kg": r["quantity_kg"],
                        "price_per_kg": r["cost_per_kg"],
                        "notes": r["notes"],
                        "created_at": r["created_at"],
                    },
                )
                conn.execute(
                    text("DELETE FROM feed_records WHERE id = :id"),
                    {"id": r["id"]},
                )
            if rows:
                print(f"[migrate] {len(rows)} pembelian pakan dipindah ke Biaya")
    except Exception as e:
        print(f"[migrate] feed_records -> cost_records dilewati: {e}")


_migrate_feed_purchases_to_costs()

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
app.include_router(feedings.router)
app.include_router(statistics.router)
app.include_router(user_management.router)
app.include_router(activity_logs.router)


def _username_from_request(request: Request):
    try:
        scheme, _, token = request.headers.get("authorization", "").partition(" ")
        if scheme.lower() != "bearer" or not token:
            return None
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        return payload.get("sub")
    except Exception:
        return None


@app.middleware("http")
async def log_writes_middleware(request: Request, call_next):
    response = await call_next(request)
    try:
        action = describe_write(request.method, request.url.path)
        username = _username_from_request(request)
        # Tulis tanpa token valid tidak dicatat (menghindari noise 401);
        # login gagal dicatat eksplisit di endpoint login.
        if action and username:
            db = SessionLocal()
            try:
                log_activity(
                    db,
                    username=username,
                    action=action,
                    detail=f"{request.method} {request.url.path} -> {response.status_code}",
                    ip=client_ip(request),
                )
            finally:
                db.close()
    except Exception:
        pass
    return response


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
