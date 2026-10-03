from pydantic import BaseModel, EmailStr
from datetime import datetime
from typing import Optional, List
from app.models import UserRole, SaleUnit, CashDirection


# ============== User Schemas ==============
class UserBase(BaseModel):
    username: str
    email: EmailStr
    full_name: str
    role: UserRole = UserRole.pegawai


class UserCreate(UserBase):
    password: str


class UserUpdate(BaseModel):
    email: Optional[EmailStr] = None
    full_name: Optional[str] = None
    role: Optional[UserRole] = None
    is_active: Optional[int] = None


class UserResponse(UserBase):
    id: int
    is_active: int
    created_at: datetime

    class Config:
        from_attributes = True


class UserLogin(BaseModel):
    username: str
    password: str


class Token(BaseModel):
    access_token: str
    token_type: str


class TokenData(BaseModel):
    username: Optional[str] = None


# ============== Egg Production Schemas ==============
class EggProductionBase(BaseModel):
    date: datetime
    total_eggs: int
    good_eggs: int
    bad_eggs: int = 0
    weight_avg: Optional[float] = None
    notes: Optional[str] = None


class EggProductionCreate(EggProductionBase):
    # Rincian per ekor (opsional). Jika diisi, total_eggs & good_eggs
    # dihitung server dari jumlah rincian.
    details: List[EggProductionDetailCreate] = []


class EggProductionUpdate(BaseModel):
    date: Optional[datetime] = None
    total_eggs: Optional[int] = None
    good_eggs: Optional[int] = None
    bad_eggs: Optional[int] = None
    weight_avg: Optional[float] = None
    notes: Optional[str] = None
    # Jika disertakan, seluruh rincian lama diganti dengan yang baru
    # dan total dihitung ulang dari rincian.
    details: Optional[List[EggProductionDetailCreate]] = None


class EggProductionResponse(EggProductionBase):
    id: int
    user_id: int
    created_at: datetime
    updated_at: Optional[datetime] = None
    details: List[EggProductionDetailResponse] = []

    class Config:
        from_attributes = True


# ============== Chicken Management Schemas ==============
class ChickenManagementBase(BaseModel):
    date: datetime
    total_chickens: int
    healthy_chickens: int
    sick_chickens: int = 0
    dead_chickens: int = 0
    new_chickens: int = 0
    notes: Optional[str] = None


class ChickenManagementCreate(ChickenManagementBase):
    pass


class ChickenManagementUpdate(BaseModel):
    date: Optional[datetime] = None
    total_chickens: Optional[int] = None
    healthy_chickens: Optional[int] = None
    sick_chickens: Optional[int] = None
    dead_chickens: Optional[int] = None
    new_chickens: Optional[int] = None
    notes: Optional[str] = None


class ChickenManagementResponse(ChickenManagementBase):
    id: int
    user_id: int
    created_at: datetime
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True


# ============== Feed Record Schemas ==============
class FeedRecordBase(BaseModel):
    date: datetime
    feed_type: str
    quantity_kg: float
    cost_per_kg: float
    total_cost: float
    notes: Optional[str] = None


class FeedRecordCreate(FeedRecordBase):
    pass


class FeedRecordUpdate(BaseModel):
    date: Optional[datetime] = None
    feed_type: Optional[str] = None
    quantity_kg: Optional[float] = None
    cost_per_kg: Optional[float] = None
    total_cost: Optional[float] = None
    notes: Optional[str] = None


class FeedRecordResponse(FeedRecordBase):
    id: int
    user_id: int
    created_at: datetime
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True


# ============== Cost Record Schemas ==============
class CostRecordBase(BaseModel):
    date: datetime
    category: str
    subcategory: Optional[str] = None
    description: str
    amount: float
    notes: Optional[str] = None


class CostRecordCreate(CostRecordBase):
    pass


class CostRecordUpdate(BaseModel):
    date: Optional[datetime] = None
    category: Optional[str] = None
    subcategory: Optional[str] = None
    description: Optional[str] = None
    amount: Optional[float] = None
    notes: Optional[str] = None


class CostRecordResponse(CostRecordBase):
    id: int
    user_id: int
    created_at: datetime
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True


# ============== Egg Sale Schemas ==============
class EggSaleBase(BaseModel):
    date: datetime
    unit: SaleUnit = SaleUnit.butir
    quantity: float
    price_per_unit: float
    notes: Optional[str] = None


class EggSaleCreate(EggSaleBase):
    # total_price dihitung server (quantity * price_per_unit)
    pass


class EggSaleUpdate(BaseModel):
    date: Optional[datetime] = None
    unit: Optional[SaleUnit] = None
    quantity: Optional[float] = None
    price_per_unit: Optional[float] = None
    notes: Optional[str] = None


class EggSaleResponse(EggSaleBase):
    id: int
    user_id: int
    total_price: float
    created_at: datetime
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True


# ============== Cash Transaction Schemas ==============
class CashTransactionBase(BaseModel):
    date: datetime
    direction: CashDirection
    category: str
    description: str
    amount: float
    notes: Optional[str] = None


class CashTransactionCreate(CashTransactionBase):
    pass


class CashTransactionUpdate(BaseModel):
    date: Optional[datetime] = None
    direction: Optional[CashDirection] = None
    category: Optional[str] = None
    description: Optional[str] = None
    amount: Optional[float] = None
    notes: Optional[str] = None


class CashTransactionResponse(CashTransactionBase):
    id: int
    user_id: int
    created_at: datetime
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True


# ============== Chicken Schemas ==============
class ChickenBase(BaseModel):
    code: str
    name: Optional[str] = None
    breed: Optional[str] = None
    acquired_date: Optional[datetime] = None
    status: str = "aktif"
    notes: Optional[str] = None


class ChickenCreate(ChickenBase):
    pass


class ChickenUpdate(BaseModel):
    code: Optional[str] = None
    name: Optional[str] = None
    breed: Optional[str] = None
    acquired_date: Optional[datetime] = None
    status: Optional[str] = None
    notes: Optional[str] = None


class ChickenResponse(ChickenBase):
    id: int
    user_id: int
    photo_path: Optional[str] = None
    created_at: datetime
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True


# ============== Egg Production Detail Schemas ==============
class EggProductionDetailCreate(BaseModel):
    chicken_id: int
    eggs: int


class EggProductionDetailResponse(BaseModel):
    id: int
    chicken_id: int
    eggs: int
    chicken_code: str = ""
    chicken_name: Optional[str] = None

    class Config:
        from_attributes = True


# ============== Statistics Schemas ==============
class DailyStatistics(BaseModel):
    date: datetime
    total_eggs: int
    good_eggs: int
    bad_eggs: int
    total_chickens: int
    healthy_chickens: int
    feed_cost: float
    other_cost: float
    sales_revenue: float = 0


class MonthlyStatistics(BaseModel):
    year: int
    month: int
    total_eggs: int
    good_eggs: int
    bad_eggs: int
    avg_daily_eggs: float
    total_feed_cost: float
    total_other_cost: float
    total_sales_revenue: float = 0
    total_other_income: float = 0
    total_other_expense: float = 0
    total_chickens_end: int
