from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session, selectinload
from typing import List, Optional
from datetime import datetime, date
from app.database import get_db
from app.auth import get_current_active_user, require_editor, can_view_all_data
from app.models import User, EggProduction, EggProductionDetail, Chicken
from app.schemas import (
    EggProductionCreate,
    EggProductionUpdate,
    EggProductionResponse,
    EggProductionDetailCreate,
    EggProductionDetailResponse,
)

router = APIRouter(prefix="/api/egg-productions", tags=["Egg Productions"])


def _details_options():
    return selectinload(EggProduction.details).selectinload(
        EggProductionDetail.chicken
    )


def _to_response(p: EggProduction) -> EggProductionResponse:
    return EggProductionResponse(
        date=p.date,
        total_eggs=p.total_eggs,
        good_eggs=p.good_eggs,
        bad_eggs=p.bad_eggs,
        weight_avg=p.weight_avg,
        notes=p.notes,
        id=p.id,
        user_id=p.user_id,
        created_at=p.created_at,
        updated_at=p.updated_at,
        details=[
            EggProductionDetailResponse(
                id=d.id,
                chicken_id=d.chicken_id,
                eggs=d.eggs,
                chicken_code=d.chicken.code if d.chicken else "",
                chicken_name=d.chicken.name if d.chicken else None,
            )
            for d in (p.details or [])
        ],
    )


def _resolve_details(
    db: Session,
    details: List[EggProductionDetailCreate],
    current_user: User,
) -> int:
    """Validasi rincian; kembalikan total butir. Raise HTTPException jika invalid."""
    seen = set()
    total = 0
    for item in details:
        if item.eggs <= 0:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Jumlah telur per ayam harus lebih dari 0",
            )
        if item.chicken_id in seen:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Satu ayam hanya boleh muncul sekali per catatan",
            )
        seen.add(item.chicken_id)
        chicken = (
            db.query(Chicken).filter(Chicken.id == item.chicken_id).first()
        )
        if not chicken:
            raise HTTPException(
                status_code=404,
                detail=f"Ayam id={item.chicken_id} tidak terdaftar",
            )
        if (
            not can_view_all_data(current_user)
            and chicken.user_id != current_user.id
        ):
            raise HTTPException(
                status_code=403,
                detail="Not authorized to use this chicken",
            )
        total += item.eggs
    return total


@router.post("/", response_model=EggProductionResponse)
def create_egg_production(
    production: EggProductionCreate,
    current_user: User = Depends(require_editor),
    db: Session = Depends(get_db)
):
    data = production.dict(exclude={"details"})
    details = production.details or []
    if details:
        # Total mengikuti jumlah rincian agar selalu konsisten.
        total = _resolve_details(db, details, current_user)
        data["total_eggs"] = total
        data["good_eggs"] = total

    db_production = EggProduction(**data, user_id=current_user.id)
    db.add(db_production)
    db.flush()
    for item in details:
        db.add(
            EggProductionDetail(
                production_id=db_production.id,
                chicken_id=item.chicken_id,
                eggs=item.eggs,
            )
        )
    db.commit()
    db_production = (
        db.query(EggProduction)
        .options(_details_options())
        .filter(EggProduction.id == db_production.id)
        .first()
    )
    return _to_response(db_production)


@router.get("/", response_model=List[EggProductionResponse])
def get_egg_productions(
    skip: int = 0,
    limit: int = 100,
    start_date: Optional[date] = None,
    end_date: Optional[date] = None,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    query = db.query(EggProduction).options(_details_options())

    # Admin & investor melihat semua data; pegawai hanya data miliknya
    if not can_view_all_data(current_user):
        query = query.filter(EggProduction.user_id == current_user.id)

    if start_date:
        query = query.filter(EggProduction.date >= start_date)
    if end_date:
        query = query.filter(EggProduction.date <= end_date)

    productions = (
        query.order_by(EggProduction.date.desc())
        .offset(skip)
        .limit(limit)
        .all()
    )
    return [_to_response(p) for p in productions]


@router.get("/{production_id}", response_model=EggProductionResponse)
def get_egg_production(
    production_id: int,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    production = (
        db.query(EggProduction)
        .options(_details_options())
        .filter(EggProduction.id == production_id)
        .first()
    )
    if not production:
        raise HTTPException(status_code=404, detail="Production record not found")

    # Check permission
    if not can_view_all_data(current_user) and production.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to access this record")

    return _to_response(production)


@router.put("/{production_id}", response_model=EggProductionResponse)
def update_egg_production(
    production_id: int,
    production_update: EggProductionUpdate,
    current_user: User = Depends(require_editor),
    db: Session = Depends(get_db)
):
    production = (
        db.query(EggProduction)
        .options(_details_options())
        .filter(EggProduction.id == production_id)
        .first()
    )
    if not production:
        raise HTTPException(status_code=404, detail="Production record not found")

    # Check permission
    if not can_view_all_data(current_user) and production.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to update this record")

    update_data = production_update.dict(exclude_unset=True)
    new_details = update_data.pop("details", None)

    for field, value in update_data.items():
        setattr(production, field, value)

    if new_details is not None:
        detail_items = [
            EggProductionDetailCreate(**d) if isinstance(d, dict) else d
            for d in new_details
        ]
        total = _resolve_details(db, detail_items, current_user)
        # Ganti seluruh rincian lama + hitung ulang total.
        for old in list(production.details):
            db.delete(old)
        db.flush()
        for item in detail_items:
            db.add(
                EggProductionDetail(
                    production_id=production.id,
                    chicken_id=item.chicken_id,
                    eggs=item.eggs,
                )
            )
        production.total_eggs = total
        production.good_eggs = total

    db.commit()
    production = (
        db.query(EggProduction)
        .options(_details_options())
        .filter(EggProduction.id == production_id)
        .first()
    )
    return _to_response(production)


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
