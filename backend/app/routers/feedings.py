from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import func
from typing import Dict, List, Optional
from datetime import date
from app.database import get_db
from app.auth import get_current_active_user, require_editor, can_view_all_data
from app.models import User, Feeding, CostRecord
from app.schemas import FeedingCreate, FeedingUpdate, FeedingResponse

router = APIRouter(prefix="/api/feedings", tags=["Feedings"])


def stock_map(db: Session) -> Dict[str, float]:
    """Sisa stok per jenis pakan = pembelian (Biaya pakan) − pemberian.

    Dihitung global (satu kandang), tanpa filter user.
    """
    purchased = dict(
        db.query(
            CostRecord.feed_type,
            func.coalesce(func.sum(CostRecord.quantity_kg), 0),
        )
        .filter(
            CostRecord.category == "pakan",
            CostRecord.feed_type.isnot(None),
            CostRecord.quantity_kg.isnot(None),
        )
        .group_by(CostRecord.feed_type)
        .all()
    )
    used = dict(
        db.query(
            Feeding.feed_type,
            func.coalesce(func.sum(Feeding.quantity_kg), 0),
        )
        .group_by(Feeding.feed_type)
        .all()
    )
    stock = {}
    for feed_type in set(purchased) | set(used):
        stock[feed_type] = round(
            float(purchased.get(feed_type, 0))
            - float(used.get(feed_type, 0)),
            2,
        )
    return stock


def _check_stock(
    db: Session,
    feed_type: str,
    quantity_kg: float,
    exclude_feeding_id: Optional[int] = None,
):
    if quantity_kg <= 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Jumlah pakan harus lebih dari 0",
        )
    stock = stock_map(db).get(feed_type, 0)
    if exclude_feeding_id is not None:
        own = (
            db.query(Feeding)
            .filter(Feeding.id == exclude_feeding_id)
            .first()
        )
        if own is not None and own.feed_type == feed_type:
            stock += float(own.quantity_kg)
    if quantity_kg - stock > 1e-9:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Stok '{feed_type}' tidak cukup (sisa {stock} kg)",
        )


@router.get("/stock", response_model=Dict[str, float])
def get_feed_stock(
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db),
):
    """Sisa stok per jenis pakan (global, satu kandang)."""
    return stock_map(db)


@router.post("/", response_model=FeedingResponse)
def create_feeding(
    feeding: FeedingCreate,
    current_user: User = Depends(require_editor),
    db: Session = Depends(get_db)
):
    _check_stock(db, feeding.feed_type, feeding.quantity_kg)
    db_feeding = Feeding(**feeding.dict(), user_id=current_user.id)
    db.add(db_feeding)
    db.commit()
    db.refresh(db_feeding)
    return db_feeding


@router.get("/", response_model=List[FeedingResponse])
def get_feedings(
    skip: int = 0,
    limit: int = 100,
    start_date: Optional[date] = None,
    end_date: Optional[date] = None,
    feed_type: Optional[str] = None,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    query = db.query(Feeding)

    if not can_view_all_data(current_user):
        query = query.filter(Feeding.user_id == current_user.id)

    if start_date:
        query = query.filter(Feeding.date >= start_date)
    if end_date:
        query = query.filter(Feeding.date <= end_date)
    if feed_type:
        query = query.filter(Feeding.feed_type == feed_type)

    return query.order_by(Feeding.date.desc()).offset(skip).limit(limit).all()


@router.get("/{feeding_id}", response_model=FeedingResponse)
def get_feeding(
    feeding_id: int,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    feeding = db.query(Feeding).filter(Feeding.id == feeding_id).first()
    if not feeding:
        raise HTTPException(status_code=404, detail="Feeding not found")

    if not can_view_all_data(current_user) and feeding.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to access this record")

    return feeding


@router.put("/{feeding_id}", response_model=FeedingResponse)
def update_feeding(
    feeding_id: int,
    feeding_update: FeedingUpdate,
    current_user: User = Depends(require_editor),
    db: Session = Depends(get_db)
):
    feeding = db.query(Feeding).filter(Feeding.id == feeding_id).first()
    if not feeding:
        raise HTTPException(status_code=404, detail="Feeding not found")

    if not can_view_all_data(current_user) and feeding.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to update this record")

    update_data = feeding_update.dict(exclude_unset=True)
    new_type = update_data.get("feed_type", feeding.feed_type)
    new_qty = update_data.get("quantity_kg", feeding.quantity_kg)
    _check_stock(db, new_type, float(new_qty), exclude_feeding_id=feeding.id)

    for field, value in update_data.items():
        setattr(feeding, field, value)

    db.commit()
    db.refresh(feeding)
    return feeding


@router.delete("/{feeding_id}")
def delete_feeding(
    feeding_id: int,
    current_user: User = Depends(require_editor),
    db: Session = Depends(get_db)
):
    feeding = db.query(Feeding).filter(Feeding.id == feeding_id).first()
    if not feeding:
        raise HTTPException(status_code=404, detail="Feeding not found")

    if not can_view_all_data(current_user) and feeding.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to delete this record")

    db.delete(feeding)
    db.commit()
    return {"message": "Feeding deleted successfully"}
