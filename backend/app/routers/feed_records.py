from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from typing import List, Optional
from datetime import date
from app.database import get_db
from app.auth import get_current_active_user, require_admin
from app.models import User, FeedRecord
from app.schemas import FeedRecordCreate, FeedRecordUpdate, FeedRecordResponse

router = APIRouter(prefix="/api/feed-records", tags=["Feed Records"])


@router.post("/", response_model=FeedRecordResponse)
def create_feed_record(
    record: FeedRecordCreate,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    db_record = FeedRecord(
        **record.dict(),
        user_id=current_user.id
    )
    db.add(db_record)
    db.commit()
    db.refresh(db_record)
    return db_record


@router.get("/", response_model=List[FeedRecordResponse])
def get_feed_records(
    skip: int = 0,
    limit: int = 100,
    start_date: Optional[date] = None,
    end_date: Optional[date] = None,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    query = db.query(FeedRecord)

    if current_user.role.value != "admin":
        query = query.filter(FeedRecord.user_id == current_user.id)

    if start_date:
        query = query.filter(FeedRecord.date >= start_date)
    if end_date:
        query = query.filter(FeedRecord.date <= end_date)

    return query.order_by(FeedRecord.date.desc()).offset(skip).limit(limit).all()


@router.get("/{record_id}", response_model=FeedRecordResponse)
def get_feed_record(
    record_id: int,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    record = db.query(FeedRecord).filter(FeedRecord.id == record_id).first()
    if not record:
        raise HTTPException(status_code=404, detail="Feed record not found")

    if current_user.role.value != "admin" and record.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to access this record")

    return record


@router.put("/{record_id}", response_model=FeedRecordResponse)
def update_feed_record(
    record_id: int,
    record_update: FeedRecordUpdate,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    record = db.query(FeedRecord).filter(FeedRecord.id == record_id).first()
    if not record:
        raise HTTPException(status_code=404, detail="Feed record not found")

    if current_user.role.value != "admin" and record.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to update this record")

    update_data = record_update.dict(exclude_unset=True)
    for field, value in update_data.items():
        setattr(record, field, value)

    db.commit()
    db.refresh(record)
    return record


@router.delete("/{record_id}")
def delete_feed_record(
    record_id: int,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    record = db.query(FeedRecord).filter(FeedRecord.id == record_id).first()
    if not record:
        raise HTTPException(status_code=404, detail="Feed record not found")

    if current_user.role.value != "admin" and record.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to delete this record")

    db.delete(record)
    db.commit()
    return {"message": "Feed record deleted successfully"}
