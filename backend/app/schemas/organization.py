from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime


class OrganizationBase(BaseModel):
    """Base organization schema"""
    name: str
    slug: str
    kind: int
    website: Optional[str] = None
    location_latitude: Optional[float] = None
    location_longitude: Optional[float] = None


class OrganizationCreate(OrganizationBase):
    """Organization creation schema"""
    pass


class OrganizationUpdate(BaseModel):
    """Organization update schema"""
    name: Optional[str] = None
    website: Optional[str] = None
    location_latitude: Optional[float] = None
    location_longitude: Optional[float] = None
    search_radius_miles: Optional[float] = None


class OrganizationResponse(OrganizationBase):
    """Organization response schema"""
    id: int
    short_name: Optional[str]
    approved: bool
    is_paid: bool
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True
