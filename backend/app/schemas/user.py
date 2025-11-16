from pydantic import BaseModel, EmailStr, Field
from typing import Optional
from datetime import datetime


class UserBase(BaseModel):
    """Base user schema"""
    email: EmailStr
    username: Optional[str] = None
    name: Optional[str] = None
    phone: Optional[str] = None
    preferred_language: Optional[str] = None


class UserCreate(UserBase):
    """User creation schema"""
    password: str = Field(..., min_length=8)
    terms_of_service: bool = True


class UserLogin(BaseModel):
    """User login schema"""
    email: EmailStr
    password: str


class UserUpdate(BaseModel):
    """User update schema"""
    username: Optional[str] = None
    name: Optional[str] = None
    description: Optional[str] = None
    phone: Optional[str] = None
    preferred_language: Optional[str] = None
    show_bikes: Optional[bool] = None
    show_phone: Optional[bool] = None
    notification_newsletters: Optional[bool] = None


class UserResponse(UserBase):
    """User response schema"""
    id: int
    username: Optional[str]
    name: Optional[str]
    confirmed: bool
    show_bikes: bool
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class Token(BaseModel):
    """Authentication token schema"""
    access_token: str
    token_type: str = "bearer"


class TokenData(BaseModel):
    """Token data schema"""
    email: Optional[str] = None
    user_id: Optional[int] = None
