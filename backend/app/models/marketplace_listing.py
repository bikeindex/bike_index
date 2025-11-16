from datetime import datetime
from sqlalchemy import Column, Integer, String, Boolean, Text, DateTime, Float, BigInteger
from sqlalchemy.orm import relationship
from enum import Enum
from ..database import Base


class ListingCondition(str, Enum):
    """Marketplace listing condition"""
    new = "new"
    excellent = "excellent"
    good = "good"
    fair = "fair"
    poor = "poor"
    salvage = "salvage"


class MarketplaceListing(Base):
    """Marketplace listing model"""

    __tablename__ = "marketplace_listings"

    # Primary Key
    id = Column(Integer, primary_key=True, index=True)

    # Listing Details
    title = Column(String(255), nullable=False)
    description = Column(Text)
    price = Column(Integer)  # Price in cents
    currency = Column(String(3), default="USD")
    condition = Column(String(50))  # ListingCondition enum

    # Associated Items
    bike_id = Column(Integer, index=True)
    user_id = Column(Integer, nullable=False, index=True)

    # Location
    latitude = Column(Float)
    longitude = Column(Float)
    city = Column(String(255))
    state = Column(String(255))
    country = Column(String(255))
    zipcode = Column(String(255))

    # Status
    active = Column(Boolean, default=True, nullable=False)
    sold = Column(Boolean, default=False, nullable=False)
    sold_at = Column(DateTime)

    # Contact
    contact_email = Column(String(255))
    contact_phone = Column(String(255))
    show_email = Column(Boolean, default=True)
    show_phone = Column(Boolean, default=True)

    # Images
    image_urls = Column(Text)  # JSON array of image URLs

    # Soft Delete
    deleted_at = Column(DateTime)

    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

    # Relationships
    # user = relationship("User", back_populates="marketplace_listings")
    # bike = relationship("Bike", back_populates="marketplace_listings")
    # messages = relationship("MarketplaceMessage", back_populates="listing")
