from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.config import get_settings
from app.database import engine, Base
from app.routers import auth, egg_production, chicken_management, feed_records, cost_records, statistics, user_management

settings = get_settings()

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
