from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from typing import List, Optional
from datetime import datetime, date
from app.database import get_db
from app.auth import get_current_active_user, require_editor, can_view_all_data
from app.models import User, EggProduction
from app.schemas import EggProductionCreate, EggProductionUpdate, EggProductionResponse

router = APIRouter(prefix="/api/egg-productions", tags=["Egg Productions"])


@router.post("/", response_model=EggProductionResponse)
def create_egg_production(
    production: EggProductionCreate,
    current_user: User = Depends(require_editor),
    db: Session = Depends(get_db)
):
    db_production = EggProduction(
        **production.dict(),
        user_id=current_user.id
    )
    db.add(db_production)
    db.commit()
    db.refresh(db_production)
    return db_production


@router.get("/", response_model=List[EggProductionResponse])
def get_egg_productions(
    skip: int = 0,
    limit: int = 100,
    start_date: Optional[date] = None,
    end_date: Optional[date] = None,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    query = db.query(EggProduction)

    # Admin & investor melihat semua data; pegawai hanya data miliknya
    if not can_view_all_data(current_user):
        query = query.filter(EggProduction.user_id == current_user.id)

    if start_date:
        query = query.filter(EggProduction.date >= start_date)
    if end_date:
        query = query.filter(EggProduction.date <= end_date)

    return query.order_by(EggProduction.date.desc()).offset(skip).limit(limit).all()


@router.get("/{production_id}", response_model=EggProductionResponse)
def get_egg_production(
    production_id: int,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    production = db.query(EggProduction).filter(EggProduction.id == production_id).first()
    if not production:
        raise HTTPException(status_code=404, detail="Production record not found")

    # Check permission
    if not can_view_all_data(current_user) and production.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to access this record")

    return production


@router.put("/{production_id}", response_model=EggProductionResponse)
def update_egg_production(
    production_id: int,
    production_update: EggProductionUpdate,
    current_user: User = Depends(require_editor),
    db: Session = Depends(get_db)
):
    production = db.query(EggProduction).filter(EggProduction.id == production_id).first()
    if not production:
        raise HTTPException(status_code=404, detail="Production record not found")

    # Check permission
    if not can_view_all_data(current_user) and production.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to update this record")

    update_data = production_update.dict(exclude_unset=True)
    for field, value in update_data.items():
        setattr(production, field, value)

    db.commit()
    db.refresh(production)
    return production


@router.delete("/{production_id}")
def delete_egg_production(
    production_id: int,
    current_user: User = Depends(require_editor),
    db: Session = Depends(get_db)
):
    production = db.query(EggProduction).filter(EggProduction.id == production_id).first()
    if not production:
        raise HTTPException(status_code=404, detail="Production record not found")

    # Check permission
    if not can_view_all_data(current_user) and production.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to delete this record")

    db.delete(production)
    db.commit()
    return {"message": "Production record deleted successfully"}
