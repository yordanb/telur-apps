from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List, Optional
from datetime import date, timedelta
from app.database import get_db
from app.auth import get_current_active_user, require_editor, can_view_all_data
from app.models import User, CashTransaction
from app.schemas import (
    CashTransactionCreate,
    CashTransactionUpdate,
    CashTransactionResponse,
)

router = APIRouter(prefix="/api/cash-transactions", tags=["Cash Transactions"])


@router.post("/", response_model=CashTransactionResponse)
def create_cash_transaction(
    tx: CashTransactionCreate,
    current_user: User = Depends(require_editor),
    db: Session = Depends(get_db)
):
    if tx.amount <= 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Nominal harus lebih dari 0",
        )
    db_tx = CashTransaction(**tx.dict(), user_id=current_user.id)
    db.add(db_tx)
    db.commit()
    db.refresh(db_tx)
    return db_tx


@router.get("/", response_model=List[CashTransactionResponse])
def get_cash_transactions(
    skip: int = 0,
    limit: int = 100,
    start_date: Optional[date] = None,
    end_date: Optional[date] = None,
    direction: Optional[str] = None,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    query = db.query(CashTransaction)

    if not can_view_all_data(current_user):
        query = query.filter(CashTransaction.user_id == current_user.id)

    if start_date:
        query = query.filter(CashTransaction.date >= start_date)
    if end_date:
        # end_date inklusif seharian penuh (bukan tengah malam awal hari)
        query = query.filter(CashTransaction.date < end_date + timedelta(days=1))
    if direction:
        query = query.filter(CashTransaction.direction == direction)

    return query.order_by(CashTransaction.date.desc()).offset(skip).limit(limit).all()


@router.get("/{tx_id}", response_model=CashTransactionResponse)
def get_cash_transaction(
    tx_id: int,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    tx = db.query(CashTransaction).filter(CashTransaction.id == tx_id).first()
    if not tx:
        raise HTTPException(status_code=404, detail="Cash transaction not found")

    if not can_view_all_data(current_user) and tx.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to access this record")

    return tx


@router.put("/{tx_id}", response_model=CashTransactionResponse)
def update_cash_transaction(
    tx_id: int,
    tx_update: CashTransactionUpdate,
    current_user: User = Depends(require_editor),
    db: Session = Depends(get_db)
):
    tx = db.query(CashTransaction).filter(CashTransaction.id == tx_id).first()
    if not tx:
        raise HTTPException(status_code=404, detail="Cash transaction not found")

    if not can_view_all_data(current_user) and tx.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to update this record")

    update_data = tx_update.dict(exclude_unset=True)
    if "amount" in update_data and update_data["amount"] <= 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Nominal harus lebih dari 0",
        )
    for field, value in update_data.items():
        setattr(tx, field, value)

    db.commit()
    db.refresh(tx)
    return tx


@router.delete("/{tx_id}")
def delete_cash_transaction(
    tx_id: int,
    current_user: User = Depends(require_editor),
    db: Session = Depends(get_db)
):
    tx = db.query(CashTransaction).filter(CashTransaction.id == tx_id).first()
    if not tx:
        raise HTTPException(status_code=404, detail="Cash transaction not found")

    if not can_view_all_data(current_user) and tx.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to delete this record")

    db.delete(tx)
    db.commit()
    return {"message": "Cash transaction deleted successfully"}
