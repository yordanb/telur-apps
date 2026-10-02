from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List, Optional
from datetime import date
from app.database import get_db
from app.auth import get_current_active_user, require_editor, can_view_all_data
from app.models import User, EggSale
from app.schemas import EggSaleCreate, EggSaleUpdate, EggSaleResponse

router = APIRouter(prefix="/api/egg-sales", tags=["Egg Sales"])


def _calc_total(quantity: float, price_per_unit: float) -> float:
    if quantity <= 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Jumlah harus lebih dari 0",
        )
    if price_per_unit < 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Harga tidak boleh negatif",
        )
    return quantity * price_per_unit


@router.post("/", response_model=EggSaleResponse)
def create_egg_sale(
    sale: EggSaleCreate,
    current_user: User = Depends(require_editor),
    db: Session = Depends(get_db)
):
    db_sale = EggSale(
        user_id=current_user.id,
        date=sale.date,
        unit=sale.unit,
        quantity=sale.quantity,
        price_per_unit=sale.price_per_unit,
        total_price=_calc_total(sale.quantity, sale.price_per_unit),
        notes=sale.notes,
    )
    db.add(db_sale)
    db.commit()
    db.refresh(db_sale)
    return db_sale


@router.get("/", response_model=List[EggSaleResponse])
def get_egg_sales(
    skip: int = 0,
    limit: int = 100,
    start_date: Optional[date] = None,
    end_date: Optional[date] = None,
    unit: Optional[str] = None,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    query = db.query(EggSale)

    if not can_view_all_data(current_user):
        query = query.filter(EggSale.user_id == current_user.id)

    if start_date:
        query = query.filter(EggSale.date >= start_date)
    if end_date:
        query = query.filter(EggSale.date <= end_date)
    if unit:
        query = query.filter(EggSale.unit == unit)

    return query.order_by(EggSale.date.desc()).offset(skip).limit(limit).all()


@router.get("/{sale_id}", response_model=EggSaleResponse)
def get_egg_sale(
    sale_id: int,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    sale = db.query(EggSale).filter(EggSale.id == sale_id).first()
    if not sale:
        raise HTTPException(status_code=404, detail="Egg sale not found")

    if not can_view_all_data(current_user) and sale.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to access this record")

    return sale


@router.put("/{sale_id}", response_model=EggSaleResponse)
def update_egg_sale(
    sale_id: int,
    sale_update: EggSaleUpdate,
    current_user: User = Depends(require_editor),
    db: Session = Depends(get_db)
):
    sale = db.query(EggSale).filter(EggSale.id == sale_id).first()
    if not sale:
        raise HTTPException(status_code=404, detail="Egg sale not found")

    if not can_view_all_data(current_user) and sale.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to update this record")

    update_data = sale_update.dict(exclude_unset=True)
    for field, value in update_data.items():
        setattr(sale, field, value)

    # Hitung ulang total jika jumlah/harga berubah
    sale.total_price = _calc_total(float(sale.quantity), float(sale.price_per_unit))

    db.commit()
    db.refresh(sale)
    return sale


@router.delete("/{sale_id}")
def delete_egg_sale(
    sale_id: int,
    current_user: User = Depends(require_editor),
    db: Session = Depends(get_db)
):
    sale = db.query(EggSale).filter(EggSale.id == sale_id).first()
    if not sale:
        raise HTTPException(status_code=404, detail="Egg sale not found")

    if not can_view_all_data(current_user) and sale.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to delete this record")

    db.delete(sale)
    db.commit()
    return {"message": "Egg sale deleted successfully"}
