from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime


class BikeBase(BaseModel):
    """Base bike schema"""
    serial_number: str
    manufacturer_id: Optional[int] = None
    frame_model: Optional[str] = None
    year: Optional[int] = None
    description: Optional[str] = None
    primary_frame_color_id: Optional[int] = None
    secondary_frame_color_id: Optional[int] = None


class BikeCreate(BikeBase):
    """Bike creation schema"""
    pass


class BikeUpdate(BaseModel):
    """Bike update schema"""
    frame_model: Optional[str] = None
    year: Optional[int] = None
    description: Optional[str] = None
    primary_frame_color_id: Optional[int] = None
    secondary_frame_color_id: Optional[int] = None
    is_for_sale: Optional[bool] = None


class BikeResponse(BikeBase):
    """Bike response schema"""
    id: int
    name: Optional[str]
    status: int
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class BikeSearch(BaseModel):
    """Bike search schema"""
    serial_number: Optional[str] = None
    manufacturer_id: Optional[int] = None
    stolen: Optional[bool] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    distance_miles: Optional[int] = Field(default=50, le=500)
