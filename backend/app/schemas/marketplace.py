from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime


class MarketplaceListingBase(BaseModel):
    """Base marketplace listing schema"""
    title: str
    description: Optional[str] = None
    price: int = Field(..., ge=0)  # Price in cents
    condition: str
    bike_id: Optional[int] = None


class MarketplaceListingCreate(MarketplaceListingBase):
    """Marketplace listing creation schema"""
    contact_email: Optional[str] = None
    contact_phone: Optional[str] = None


class MarketplaceListingUpdate(BaseModel):
    """Marketplace listing update schema"""
    title: Optional[str] = None
    description: Optional[str] = None
    price: Optional[int] = Field(None, ge=0)
    condition: Optional[str] = None
    active: Optional[bool] = None


class MarketplaceListingResponse(MarketplaceListingBase):
    """Marketplace listing response schema"""
    id: int
    user_id: int
    active: bool
    sold: bool
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True
