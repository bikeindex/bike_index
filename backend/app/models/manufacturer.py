from datetime import datetime
from sqlalchemy import Column, Integer, String, Boolean, Text, DateTime
from sqlalchemy.orm import relationship
from ..database import Base


class Manufacturer(Base):
    """Bike manufacturer model"""

    __tablename__ = "manufacturers"

    # Primary Key
    id = Column(Integer, primary_key=True, index=True)

    # Basic Information
    name = Column(String(255), nullable=False, unique=True, index=True)
    slug = Column(String(255), unique=True, index=True)
    website = Column(String(255))
    description = Column(Text)
    logo_url = Column(String(255))

    # Frame Maker
    frame_maker = Column(Boolean, default=True)

    # Popularity & Stats
    bikes_count = Column(Integer, default=0)
    popularity_score = Column(Integer, default=0)

    # Soft Delete
    deleted_at = Column(DateTime)

    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

    # Relationships
    # bikes = relationship("Bike", back_populates="manufacturer")
    # organizations = relationship("Organization", back_populates="manufacturer")
