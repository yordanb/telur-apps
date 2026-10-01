from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from typing import List, Optional
from datetime import date
from app.database import get_db
from app.auth import get_current_active_user, require_editor, can_view_all_data
from app.models import User, ChickenManagement
from app.schemas import ChickenManagementCreate, ChickenManagementUpdate, ChickenManagementResponse

router = APIRouter(prefix="/api/chicken-managements", tags=["Chicken Managements"])


@router.post("/", response_model=ChickenManagementResponse)
def create_chicken_management(
    management: ChickenManagementCreate,
    current_user: User = Depends(require_editor),
    db: Session = Depends(get_db)
):
    db_management = ChickenManagement(
        **management.dict(),
        user_id=current_user.id
    )
    db.add(db_management)
    db.commit()
    db.refresh(db_management)
    return db_management


@router.get("/", response_model=List[ChickenManagementResponse])
def get_chicken_managements(
    skip: int = 0,
    limit: int = 100,
    start_date: Optional[date] = None,
    end_date: Optional[date] = None,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    query = db.query(ChickenManagement)

    if not can_view_all_data(current_user):
        query = query.filter(ChickenManagement.user_id == current_user.id)

    if start_date:
        query = query.filter(ChickenManagement.date >= start_date)
    if end_date:
        query = query.filter(ChickenManagement.date <= end_date)

    return query.order_by(ChickenManagement.date.desc()).offset(skip).limit(limit).all()


@router.get("/{management_id}", response_model=ChickenManagementResponse)
def get_chicken_management(
    management_id: int,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    management = db.query(ChickenManagement).filter(ChickenManagement.id == management_id).first()
    if not management:
        raise HTTPException(status_code=404, detail="Management record not found")

    if not can_view_all_data(current_user) and management.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to access this record")

    return management


@router.put("/{management_id}", response_model=ChickenManagementResponse)
def update_chicken_management(
    management_id: int,
    management_update: ChickenManagementUpdate,
    current_user: User = Depends(require_editor),
    db: Session = Depends(get_db)
):
    management = db.query(ChickenManagement).filter(ChickenManagement.id == management_id).first()
    if not management:
        raise HTTPException(status_code=404, detail="Management record not found")

    if not can_view_all_data(current_user) and management.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to update this record")

    update_data = management_update.dict(exclude_unset=True)
    for field, value in update_data.items():
        setattr(management, field, value)

    db.commit()
    db.refresh(management)
    return management


@router.delete("/{management_id}")
def delete_chicken_management(
    management_id: int,
    current_user: User = Depends(require_editor),
    db: Session = Depends(get_db)
):
    management = db.query(ChickenManagement).filter(ChickenManagement.id == management_id).first()
    if not management:
        raise HTTPException(status_code=404, detail="Management record not found")

    if not can_view_all_data(current_user) and management.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to delete this record")

    db.delete(management)
    db.commit()
    return {"message": "Management record deleted successfully"}
