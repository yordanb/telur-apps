from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from sqlalchemy import func, extract
from typing import List, Optional
from datetime import date
from app.database import get_db
from app.auth import get_current_active_user, require_admin, can_view_all_data
from app.models import User, EggProduction, ChickenManagement, FeedRecord, CostRecord
from app.schemas import DailyStatistics, MonthlyStatistics

router = APIRouter(prefix="/api/statistics", tags=["Statistics"])


@router.get("/daily", response_model=List[DailyStatistics])
def get_daily_statistics(
    start_date: Optional[date] = None,
    end_date: Optional[date] = None,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    query = db.query(
        EggProduction.date,
        func.sum(EggProduction.total_eggs).label('total_eggs'),
        func.sum(EggProduction.good_eggs).label('good_eggs'),
        func.sum(EggProduction.bad_eggs).label('bad_eggs'),
        func.sum(ChickenManagement.total_chickens).label('total_chickens'),
        func.sum(ChickenManagement.healthy_chickens).label('healthy_chickens'),
        func.sum(FeedRecord.total_cost).label('feed_cost'),
        func.sum(CostRecord.amount).label('other_cost')
    ).outerjoin(
        ChickenManagement,
        func.date(EggProduction.date) == func.date(ChickenManagement.date)
    ).outerjoin(
        FeedRecord,
        func.date(EggProduction.date) == func.date(FeedRecord.date)
    ).outerjoin(
        CostRecord,
        func.date(EggProduction.date) == func.date(CostRecord.date)
    )

    if not can_view_all_data(current_user):
        query = query.filter(EggProduction.user_id == current_user.id)

    if start_date:
        query = query.filter(EggProduction.date >= start_date)
    if end_date:
        query = query.filter(EggProduction.date <= end_date)

    query = query.group_by(EggProduction.date).order_by(EggProduction.date.desc())

    results = query.all()
    return [
        DailyStatistics(
            date=row.date,
            total_eggs=row.total_eggs or 0,
            good_eggs=row.good_eggs or 0,
            bad_eggs=row.bad_eggs or 0,
            total_chickens=row.total_chickens or 0,
            healthy_chickens=row.healthy_chickens or 0,
            feed_cost=row.feed_cost or 0,
            other_cost=row.other_cost or 0
        )
        for row in results
    ]


@router.get("/monthly", response_model=List[MonthlyStatistics])
def get_monthly_statistics(
    year: Optional[int] = None,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    if year is None:
        year = date.today().year

    # Get monthly egg production stats
    egg_stats = db.query(
        extract('year', EggProduction.date).label('year'),
        extract('month', EggProduction.date).label('month'),
        func.sum(EggProduction.total_eggs).label('total_eggs'),
        func.sum(EggProduction.good_eggs).label('good_eggs'),
        func.sum(EggProduction.bad_eggs).label('bad_eggs'),
        func.avg(EggProduction.total_eggs).label('avg_daily_eggs')
    ).filter(
        extract('year', EggProduction.date) == year
    )

    if not can_view_all_data(current_user):
        egg_stats = egg_stats.filter(EggProduction.user_id == current_user.id)

    egg_stats = egg_stats.group_by('year', 'month').all()

    # Get monthly feed costs
    feed_stats = db.query(
        extract('year', FeedRecord.date).label('year'),
        extract('month', FeedRecord.date).label('month'),
        func.sum(FeedRecord.total_cost).label('total_feed_cost')
    ).filter(
        extract('year', FeedRecord.date) == year
    )

    if not can_view_all_data(current_user):
        feed_stats = feed_stats.filter(FeedRecord.user_id == current_user.id)

    feed_stats = feed_stats.group_by('year', 'month').all()

    # Get monthly other costs
    cost_stats = db.query(
        extract('year', CostRecord.date).label('year'),
        extract('month', CostRecord.date).label('month'),
        func.sum(CostRecord.amount).label('total_other_cost')
    ).filter(
        extract('year', CostRecord.date) == year
    )

    if not can_view_all_data(current_user):
        cost_stats = cost_stats.filter(CostRecord.user_id == current_user.id)

    cost_stats = cost_stats.group_by('year', 'month').all()

    # Get chicken count at end of each month
    chicken_stats = db.query(
        extract('year', ChickenManagement.date).label('year'),
        extract('month', ChickenManagement.date).label('month'),
        func.max(ChickenManagement.total_chickens).label('total_chickens_end')
    ).filter(
        extract('year', ChickenManagement.date) == year
    )

    if not can_view_all_data(current_user):
        chicken_stats = chicken_stats.filter(ChickenManagement.user_id == current_user.id)

    chicken_stats = chicken_stats.group_by('year', 'month').all()

    # Combine results
    feed_dict = {(int(r.year), int(r.month)): r.total_feed_cost or 0 for r in feed_stats}
    cost_dict = {(int(r.year), int(r.month)): r.total_other_cost or 0 for r in cost_stats}
    chicken_dict = {(int(r.year), int(r.month)): r.total_chickens_end or 0 for r in chicken_stats}

    results = []
    for stat in egg_stats:
        year_val = int(stat.year)
        month_val = int(stat.month)
        results.append(MonthlyStatistics(
            year=year_val,
            month=month_val,
            total_eggs=stat.total_eggs or 0,
            good_eggs=stat.good_eggs or 0,
            bad_eggs=stat.bad_eggs or 0,
            avg_daily_eggs=round(stat.avg_daily_eggs or 0, 2),
            total_feed_cost=feed_dict.get((year_val, month_val), 0),
            total_other_cost=cost_dict.get((year_val, month_val), 0),
            total_chickens_end=chicken_dict.get((year_val, month_val), 0)
        ))

    return results
