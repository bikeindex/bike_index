from datetime import datetime
from sqlalchemy import Column, Integer, String, Boolean, Text, DateTime, Float, BigInteger, JSON
from sqlalchemy.orm import relationship
from enum import Enum
from ..database import Base


class OrganizationKind(int, Enum):
    """Organization kind types"""
    bike_shop = 0
    bike_advocacy = 1
    law_enforcement = 2
    school = 3
    bike_manufacturer = 4
    software = 5
    property_management = 6
    other = 7
    ambassador = 8
    bike_depot = 9


class POSKind(int, Enum):
    """Point of Sale system types"""
    no_pos = 0
    other_pos = 1
    lightspeed_pos = 2
    ascend_pos = 3
    broken_lightspeed_pos = 4
    does_not_need_pos = 5
    broken_ascend_pos = 6


class Organization(Base):
    """Organization model"""

    __tablename__ = "organizations"

    # Primary Key
    id = Column(Integer, primary_key=True, index=True)

    # Basic Information
    name = Column(String(255))
    short_name = Column(String(255))
    slug = Column(String(255), unique=True, nullable=False, index=True)
    previous_slug = Column(String)
    website = Column(String(255))
    kind = Column(Integer)  # OrganizationKind enum
    avatar = Column(String(255))

    # Status & Permissions
    approved = Column(Boolean, default=True)
    api_access_approved = Column(Boolean, default=False, nullable=False)
    is_paid = Column(Boolean, default=False, nullable=False)
    access_token = Column(String(255))

    # Location
    location_latitude = Column(Float, index=True)
    location_longitude = Column(Float, index=True)
    search_radius_miles = Column(Float, default=50.0, nullable=False)
    show_on_map = Column(Boolean)
    lock_show_on_map = Column(Boolean, default=False, nullable=False)

    # Point of Sale Integration
    pos_kind = Column(Integer, default=0)  # no_pos
    manual_pos_kind = Column(Integer)
    ascend_name = Column(String)
    lightspeed_register_with_phone = Column(Boolean, default=False)

    # Features & Configuration
    enabled_feature_slugs = Column(JSON)
    available_invitation_count = Column(Integer, default=10)
    landing_html = Column(Text)
    registration_field_labels = Column(JSON)
    graduated_notification_interval = Column(BigInteger)
    direct_unclaimed_notifications = Column(Boolean, default=False)

    # Relationships
    parent_organization_id = Column(Integer, index=True)
    manufacturer_id = Column(BigInteger, index=True)
    auto_user_id = Column(Integer)
    child_ids = Column(JSON)
    regional_ids = Column(JSON)

    # Spam & Security
    spam_registrations = Column(Boolean, default=False)
    passwordless_user_domain = Column(String)

    # Surveys & Research
    opted_into_theft_survey_2023 = Column(Boolean, default=False)

    # Soft Delete
    deleted_at = Column(DateTime)

    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

    # Relationships (to be added)
    # parent_organization = relationship("Organization", remote_side=[id])
    # bikes = relationship("Bike", secondary="bike_organizations", back_populates="organizations")
    # users = relationship("User", secondary="organization_roles", back_populates="organizations")
    # locations = relationship("Location", back_populates="organization")
