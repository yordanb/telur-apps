import os
import uuid
from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File
from sqlalchemy.orm import Session
from typing import List, Optional
from app.database import get_db
from app.auth import get_current_active_user, require_editor, can_view_all_data
from app.models import User, Chicken
from app.schemas import ChickenCreate, ChickenUpdate, ChickenResponse

router = APIRouter(prefix="/api/chickens", tags=["Chickens"])

UPLOAD_DIR = os.environ.get("UPLOAD_DIR", "/app/uploads")
ALLOWED_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}
MAX_PHOTO_BYTES = 5 * 1024 * 1024
CHICKEN_STATUSES = {"aktif", "sakit", "mati", "terjual"}


def _check_status(value: Optional[str]):
    if value is not None and value not in CHICKEN_STATUSES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Status harus salah satu dari: {', '.join(sorted(CHICKEN_STATUSES))}",
        )


def _check_owner(chicken: Chicken, current_user: User, action: str):
    if not can_view_all_data(current_user) and chicken.user_id != current_user.id:
        raise HTTPException(
            status_code=403,
            detail=f"Not authorized to {action} this chicken",
        )


@router.post("/", response_model=ChickenResponse)
def create_chicken(
    chicken: ChickenCreate,
    current_user: User = Depends(require_editor),
    db: Session = Depends(get_db)
):
    _check_status(chicken.status)
    if db.query(Chicken).filter(Chicken.code == chicken.code).first():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Kode ayam '{chicken.code}' sudah terdaftar",
        )
    db_chicken = Chicken(**chicken.dict(), user_id=current_user.id)
    db.add(db_chicken)
    db.commit()
    db.refresh(db_chicken)
    return db_chicken


@router.get("/", response_model=List[ChickenResponse])
def get_chickens(
    skip: int = 0,
    limit: int = 200,
    status_filter: Optional[str] = None,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    query = db.query(Chicken)

    if not can_view_all_data(current_user):
        query = query.filter(Chicken.user_id == current_user.id)

    if status_filter:
        query = query.filter(Chicken.status == status_filter)

    return query.order_by(Chicken.code.asc()).offset(skip).limit(limit).all()


@router.get("/{chicken_id}", response_model=ChickenResponse)
def get_chicken(
    chicken_id: int,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    chicken = db.query(Chicken).filter(Chicken.id == chicken_id).first()
    if not chicken:
        raise HTTPException(status_code=404, detail="Chicken not found")

    _check_owner(chicken, current_user, "access")
    return chicken


@router.put("/{chicken_id}", response_model=ChickenResponse)
def update_chicken(
    chicken_id: int,
    chicken_update: ChickenUpdate,
    current_user: User = Depends(require_editor),
    db: Session = Depends(get_db)
):
    chicken = db.query(Chicken).filter(Chicken.id == chicken_id).first()
    if not chicken:
        raise HTTPException(status_code=404, detail="Chicken not found")

    _check_owner(chicken, current_user, "update")
    _check_status(chicken_update.status)

    update_data = chicken_update.dict(exclude_unset=True)
    if "code" in update_data and update_data["code"] != chicken.code:
        if db.query(Chicken).filter(Chicken.code == update_data["code"]).first():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Kode ayam '{update_data['code']}' sudah terdaftar",
            )
    for field, value in update_data.items():
        setattr(chicken, field, value)

    db.commit()
    db.refresh(chicken)
    return chicken


@router.delete("/{chicken_id}")
def delete_chicken(
    chicken_id: int,
    current_user: User = Depends(require_editor),
    db: Session = Depends(get_db)
):
    chicken = db.query(Chicken).filter(Chicken.id == chicken_id).first()
    if not chicken:
        raise HTTPException(status_code=404, detail="Chicken not found")

    _check_owner(chicken, current_user, "delete")

    photo_path = chicken.photo_path
    db.delete(chicken)
    db.commit()

    if photo_path:
        _delete_photo_file(photo_path)

    return {"message": "Chicken deleted successfully"}


@router.post("/{chicken_id}/photo", response_model=ChickenResponse)
async def upload_chicken_photo(
    chicken_id: int,
    photo: UploadFile = File(...),
    current_user: User = Depends(require_editor),
    db: Session = Depends(get_db)
):
    chicken = db.query(Chicken).filter(Chicken.id == chicken_id).first()
    if not chicken:
        raise HTTPException(status_code=404, detail="Chicken not found")

    _check_owner(chicken, current_user, "update")

    ext = os.path.splitext(photo.filename or "")[1].lower()
    if ext not in ALLOWED_EXTENSIONS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Format foto harus JPG, PNG, atau WebP",
        )

    content = await photo.read()
    if len(content) > MAX_PHOTO_BYTES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Ukuran foto maksimal 5 MB",
        )
    if len(content) == 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="File foto kosong",
        )

    os.makedirs(UPLOAD_DIR, exist_ok=True)
    filename = f"chicken_{chicken_id}_{uuid.uuid4().hex}{ext}"
    filepath = os.path.join(UPLOAD_DIR, filename)
    with open(filepath, "wb") as f:
        f.write(content)

    old_photo = chicken.photo_path
    chicken.photo_path = f"uploads/{filename}"
    db.commit()
    db.refresh(chicken)

    if old_photo:
        _delete_photo_file(old_photo)

    return chicken


def _delete_photo_file(photo_path: str):
    try:
        full = os.path.join(UPLOAD_DIR, os.path.basename(photo_path))
        if os.path.isfile(full):
            os.remove(full)
    except OSError:
        pass
