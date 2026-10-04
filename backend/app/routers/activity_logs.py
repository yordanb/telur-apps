from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import desc
from typing import List, Optional
from datetime import date, timedelta
from app.database import get_db
from app.auth import require_admin
from app.models import User, ActivityLog
from app.schemas import ActivityLogResponse

router = APIRouter(prefix="/api/activity-logs", tags=["Activity Logs"])


@router.get("/", response_model=List[ActivityLogResponse])
def get_activity_logs(
    skip: int = 0,
    limit: int = 100,
    start_date: Optional[date] = None,
    end_date: Optional[date] = None,
    action: Optional[str] = None,
    username: Optional[str] = None,
    current_user: User = Depends(require_admin),
    db: Session = Depends(get_db)
):
    """Jejak audit — khusus admin. Pola filter sama seperti modul lain."""
    query = db.query(ActivityLog)

    if start_date:
        query = query.filter(ActivityLog.created_at >= start_date)
    if end_date:
        # end_date inklusif seharian penuh (bukan tengah malam awal hari)
        query = query.filter(ActivityLog.created_at < end_date + timedelta(days=1))
    if action:
        query = query.filter(ActivityLog.action == action)
    if username:
        query = query.filter(ActivityLog.username.ilike(f"%{username}%"))

    return (
        query.order_by(desc(ActivityLog.created_at))
        .offset(skip)
        .limit(limit)
        .all()
    )
