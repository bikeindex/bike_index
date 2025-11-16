from datetime import datetime
from sqlalchemy import Column, Integer, String, Boolean, Text, DateTime, Float, BigInteger, JSON
from sqlalchemy.orm import relationship
from ..database import Base


class User(Base):
    """User model"""

    __tablename__ = "users"

    # Primary Key
    id = Column(Integer, primary_key=True, index=True)

    # Authentication & Security
    email = Column(String(255), unique=True, index=True)
    password_digest = Column(String(255))
    auth_token = Column(String(255), index=True)
    magic_link_token = Column(Text)
    token_for_password_reset = Column(Text, index=True)
    confirmation_token = Column(String(255))
    confirmed = Column(Boolean, default=False, nullable=False)
    terms_of_service = Column(Boolean, default=False, nullable=False)
    vendor_terms_of_service = Column(Boolean)
    when_vendor_terms_of_service = Column(DateTime)

    # Profile Information
    username = Column(String(255))
    name = Column(String(255))
    title = Column(Text)
    description = Column(Text)
    avatar = Column(String(255))
    phone = Column(String(255))
    preferred_language = Column(String)

    # Social Media
    twitter = Column(String(255))
    instagram = Column(String)
    show_twitter = Column(Boolean, default=False, nullable=False)
    show_instagram = Column(Boolean, default=False)
    show_website = Column(Boolean, default=False, nullable=False)
    show_phone = Column(Boolean, default=True)
    show_bikes = Column(Boolean, default=False, nullable=False)

    # Location
    latitude = Column(Float)
    longitude = Column(Float)
    address_set_manually = Column(Boolean, default=False)
    no_address = Column(Boolean, default=False)
    address_record_id = Column(BigInteger, index=True)

    # Permissions & Roles
    admin_options = Column(JSON)
    superuser = Column(Boolean, default=False, nullable=False)
    developer = Column(Boolean, default=False, nullable=False)
    banned = Column(Boolean, default=False, nullable=False)
    can_send_many_stolen_notifications = Column(Boolean, default=False, nullable=False)

    # Notifications & Preferences
    notification_newsletters = Column(Boolean, default=False, nullable=False)
    notification_unstolen = Column(Boolean, default=True)
    no_non_theft_notification = Column(Boolean, default=False)
    alert_slugs = Column(JSON)

    # User Data & Tracking
    my_bikes_hash = Column(JSON)
    partner_data = Column(JSON)
    last_login_at = Column(DateTime)
    last_login_ip = Column(String)
    time_single_format = Column(Boolean, default=False)

    # External IDs
    stripe_id = Column(String(255))

    # Soft Delete
    deleted_at = Column(DateTime)

    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

    # Relationships (to be added)
    # bikes = relationship("Bike", back_populates="creator")
    # ownerships = relationship("Ownership", back_populates="user")
    # organizations = relationship("Organization", secondary="organization_roles", back_populates="users")
    # marketplace_listings = relationship("MarketplaceListing", back_populates="user")
