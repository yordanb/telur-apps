from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from typing import List, Optional
from datetime import date
from app.database import get_db
from app.auth import get_current_active_user, require_editor, can_view_all_data
from app.models import User, CostRecord
from app.schemas import CostRecordCreate, CostRecordUpdate, CostRecordResponse

router = APIRouter(prefix="/api/cost-records", tags=["Cost Records"])


@router.post("/", response_model=CostRecordResponse)
def create_cost_record(
    record: CostRecordCreate,
    current_user: User = Depends(require_editor),
    db: Session = Depends(get_db)
):
    db_record = CostRecord(
        **record.dict(),
        user_id=current_user.id
    )
    db.add(db_record)
    db.commit()
    db.refresh(db_record)
    return db_record


@router.get("/", response_model=List[CostRecordResponse])
def get_cost_records(
    skip: int = 0,
    limit: int = 100,
    start_date: Optional[date] = None,
    end_date: Optional[date] = None,
    category: Optional[str] = None,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    query = db.query(CostRecord)

    if not can_view_all_data(current_user):
        query = query.filter(CostRecord.user_id == current_user.id)

    if start_date:
        query = query.filter(CostRecord.date >= start_date)
    if end_date:
        query = query.filter(CostRecord.date <= end_date)
    if category:
        query = query.filter(CostRecord.category == category)

    return query.order_by(CostRecord.date.desc()).offset(skip).limit(limit).all()


@router.get("/{record_id}", response_model=CostRecordResponse)
def get_cost_record(
    record_id: int,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    record = db.query(CostRecord).filter(CostRecord.id == record_id).first()
    if not record:
        raise HTTPException(status_code=404, detail="Cost record not found")

    if not can_view_all_data(current_user) and record.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to access this record")

    return record


@router.put("/{record_id}", response_model=CostRecordResponse)
def update_cost_record(
    record_id: int,
    record_update: CostRecordUpdate,
    current_user: User = Depends(require_editor),
    db: Session = Depends(get_db)
):
    record = db.query(CostRecord).filter(CostRecord.id == record_id).first()
    if not record:
        raise HTTPException(status_code=404, detail="Cost record not found")

    if not can_view_all_data(current_user) and record.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to update this record")

    update_data = record_update.dict(exclude_unset=True)
    for field, value in update_data.items():
        setattr(record, field, value)

    db.commit()
    db.refresh(record)
    return record


@router.delete("/{record_id}")
def delete_cost_record(
    record_id: int,
    current_user: User = Depends(require_editor),
    db: Session = Depends(get_db)
):
    record = db.query(CostRecord).filter(CostRecord.id == record_id).first()
    if not record:
        raise HTTPException(status_code=404, detail="Cost record not found")

    if not can_view_all_data(current_user) and record.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to delete this record")

    db.delete(record)
    db.commit()
    return {"message": "Cost record deleted successfully"}
