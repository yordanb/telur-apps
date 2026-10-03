from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey, Enum, Text
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.database import Base
import enum


class UserRole(str, enum.Enum):
    admin = "admin"
    pegawai = "pegawai"
    investor = "investor"


class SaleUnit(str, enum.Enum):
    butir = "butir"
    kg = "kg"


class CashDirection(str, enum.Enum):
    masuk = "masuk"
    keluar = "keluar"


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    username = Column(String(50), unique=True, index=True, nullable=False)
    email = Column(String(100), unique=True, index=True, nullable=False)
    hashed_password = Column(String(255), nullable=False)
    full_name = Column(String(100), nullable=False)
    role = Column(Enum(UserRole), default=UserRole.pegawai)
    is_active = Column(Integer, default=1)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    # Relationships
    egg_productions = relationship("EggProduction", back_populates="user")
    chicken_managements = relationship("ChickenManagement", back_populates="user")
    feed_records = relationship("FeedRecord", back_populates="user")
    cost_records = relationship("CostRecord", back_populates="user")
    egg_sales = relationship("EggSale", back_populates="user")
    cash_transactions = relationship("CashTransaction", back_populates="user")
    chickens = relationship("Chicken", back_populates="user")


class EggProduction(Base):
    __tablename__ = "egg_productions"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    date = Column(DateTime(timezone=True), nullable=False)
    total_eggs = Column(Integer, nullable=False)
    good_eggs = Column(Integer, nullable=False)
    bad_eggs = Column(Integer, default=0)
    weight_avg = Column(Float, nullable=True)  # in grams
    notes = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    # Relationships
    user = relationship("User", back_populates="egg_productions")
    details = relationship(
        "EggProductionDetail",
        back_populates="production",
        cascade="all, delete-orphan",
    )


class ChickenManagement(Base):
    __tablename__ = "chicken_managements"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    date = Column(DateTime(timezone=True), nullable=False)
    total_chickens = Column(Integer, nullable=False)
    healthy_chickens = Column(Integer, nullable=False)
    sick_chickens = Column(Integer, default=0)
    dead_chickens = Column(Integer, default=0)
    new_chickens = Column(Integer, default=0)
    notes = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    # Relationships
    user = relationship("User", back_populates="chicken_managements")


class FeedRecord(Base):
    __tablename__ = "feed_records"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    date = Column(DateTime(timezone=True), nullable=False)
    feed_type = Column(String(100), nullable=False)
    quantity_kg = Column(Float, nullable=False)
    cost_per_kg = Column(Float, nullable=False)
    total_cost = Column(Float, nullable=False)
    notes = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    # Relationships
    user = relationship("User", back_populates="feed_records")


class CostRecord(Base):
    __tablename__ = "cost_records"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    date = Column(DateTime(timezone=True), nullable=False)
    category = Column(String(50), nullable=False)  # pakan, obat, operasional, lainnya
    subcategory = Column(String(100), nullable=True)  # khusus operasional: perbaikan/perawatan/pembuatan kandang
    description = Column(String(255), nullable=False)
    amount = Column(Float, nullable=False)
    notes = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    # Relationships
    user = relationship("User", back_populates="cost_records")


class CashTransaction(Base):
    __tablename__ = "cash_transactions"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    date = Column(DateTime(timezone=True), nullable=False)
    direction = Column(Enum(CashDirection), nullable=False)  # masuk | keluar
    category = Column(String(100), nullable=False)
    description = Column(String(255), nullable=False)
    amount = Column(Float, nullable=False)
    notes = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    # Relationships
    user = relationship("User", back_populates="cash_transactions")


class Chicken(Base):
    """Register ayam per ekor. Status: aktif | sakit | mati | terjual."""

    __tablename__ = "chickens"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    code = Column(String(50), unique=True, index=True, nullable=False)
    name = Column(String(100), nullable=True)
    breed = Column(String(100), nullable=True)
    acquired_date = Column(DateTime(timezone=True), nullable=True)
    status = Column(String(20), nullable=False, default="aktif")
    photo_path = Column(String(255), nullable=True)  # relatif thd /uploads
    notes = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    # Relationships
    user = relationship("User", back_populates="chickens")
    production_details = relationship(
        "EggProductionDetail",
        back_populates="chicken",
        cascade="all, delete-orphan",
    )


class EggProductionDetail(Base):
    """Rincian telur per ekor ayam dalam satu catatan produksi harian."""

    __tablename__ = "egg_production_details"

    id = Column(Integer, primary_key=True, index=True)
    production_id = Column(
        Integer, ForeignKey("egg_productions.id", ondelete="CASCADE"),
        nullable=False,
    )
    chicken_id = Column(
        Integer, ForeignKey("chickens.id", ondelete="CASCADE"),
        nullable=False,
    )
    eggs = Column(Integer, nullable=False)  # butir baik dari ayam ini

    # Relationships
    production = relationship("EggProduction", back_populates="details")
    chicken = relationship("Chicken", back_populates="production_details")


class EggSale(Base):
    __tablename__ = "egg_sales"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    date = Column(DateTime(timezone=True), nullable=False)
    unit = Column(Enum(SaleUnit), nullable=False, default=SaleUnit.butir)  # butir | kg
    quantity = Column(Float, nullable=False)  # jumlah butir atau kg
    price_per_unit = Column(Float, nullable=False)  # Rp per butir atau per kg
    total_price = Column(Float, nullable=False)  # quantity * price_per_unit (dihitung server)
    notes = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    # Relationships
    user = relationship("User", back_populates="egg_sales")
