from datetime import datetime
from sqlalchemy import Column, Integer, String, Boolean, DateTime
from sqlalchemy.orm import relationship
from ..database import Base


class Color(Base):
    """Color model for bike frame colors"""

    __tablename__ = "colors"

    # Primary Key
    id = Column(Integer, primary_key=True, index=True)

    # Color Information
    name = Column(String(255), nullable=False, unique=True)
    slug = Column(String(255), unique=True, index=True)
    priority = Column(Integer, default=0)
    display = Column(String(255))

    # Soft Delete
    deleted_at = Column(DateTime)

    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

    # Relationships
    # primary_bikes = relationship("Bike", foreign_keys="Bike.primary_frame_color_id", back_populates="primary_color")
    # secondary_bikes = relationship("Bike", foreign_keys="Bike.secondary_frame_color_id", back_populates="secondary_color")
    # tertiary_bikes = relationship("Bike", foreign_keys="Bike.tertiary_frame_color_id", back_populates="tertiary_color")
