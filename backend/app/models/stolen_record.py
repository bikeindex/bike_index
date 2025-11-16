from datetime import datetime
from sqlalchemy import Column, Integer, String, Boolean, Text, DateTime, Float, BigInteger, JSON
from sqlalchemy.orm import relationship
from ..database import Base


class StolenRecord(Base):
    """Stolen bike record model"""

    __tablename__ = "stolen_records"

    # Primary Key
    id = Column(Integer, primary_key=True, index=True)

    # Associated Bike
    bike_id = Column(Integer, nullable=False, index=True)

    # Theft Details
    date_stolen = Column(DateTime)
    theft_description = Column(Text)
    police_report_number = Column(String(255))
    police_report_department = Column(String(255))

    # Location
    latitude = Column(Float)
    longitude = Column(Float)
    city = Column(String(255))
    state = Column(String(255))
    country = Column(String(255))
    zipcode = Column(String(255))
    street = Column(String(255))

    # Locking Information
    lock_defeat_description = Column(Text)
    locking_description = Column(Text)

    # Recovery Information
    recovered = Column(Boolean, default=False, nullable=False)
    recovered_at = Column(DateTime)
    recovered_description = Column(Text)

    # Display Options
    show_address = Column(Boolean, default=True)
    receive_notifications = Column(Boolean, default=True)

    # Soft Delete
    deleted_at = Column(DateTime)

    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

    # Relationships
    # bike = relationship("Bike", back_populates="stolen_records")
