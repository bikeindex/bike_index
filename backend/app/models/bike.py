from datetime import datetime
from sqlalchemy import Column, Integer, String, Boolean, Text, DateTime, Float, BigInteger, Enum as SQLEnum
from sqlalchemy.orm import relationship
from enum import Enum
from ..database import Base


class CycleType(str, Enum):
    """Bike cycle types"""
    bike = "bike"
    tandem = "tandem"
    tricycle = "tricycle"
    unicycle = "unicycle"
    recumbent = "recumbent"
    cargo = "cargo"
    trailer = "trailer"
    stroller = "stroller"
    wheelchair = "wheelchair"


class PropulsionType(str, Enum):
    """Bike propulsion types"""
    foot_pedal = "foot-pedal"
    electric_assist = "electric-assist"
    electric_throttle = "electric-throttle"
    hand_pedal = "hand-pedal"


class BikeStatus(str, Enum):
    """Bike status"""
    status_with_owner = "status_with_owner"
    status_stolen = "status_stolen"
    status_impounded = "status_impounded"
    status_abandoned = "status_abandoned"


class FrameMaterial(int, Enum):
    """Frame material types"""
    steel = 0
    aluminum = 1
    titanium = 2
    carbon = 3
    stainless = 4
    wood = 5
    bamboo = 6
    other = 7


class HandlebarType(int, Enum):
    """Handlebar types"""
    drop = 0
    flat = 1
    riser = 2
    cruiser = 3
    bullhorn = 4
    mustache = 5
    bmx = 6
    forward = 7
    other = 8


class Bike(Base):
    """Bike model"""

    __tablename__ = "bikes"

    # Primary Key
    id = Column(Integer, primary_key=True, index=True)

    # Basic Information
    name = Column(String(255))
    serial_number = Column(String(255), nullable=False)
    serial_normalized = Column(String(255))
    serial_normalized_no_space = Column(String)
    frame_model = Column(Text)
    year = Column(Integer)
    description = Column(Text)
    all_description = Column(Text)

    # Manufacturer
    manufacturer_id = Column(Integer, index=True)
    manufacturer_other = Column(String(255))
    mnfg_name = Column(String(255))

    # Physical Characteristics
    cycle_type = Column(Integer, default=0)  # bike
    propulsion_type = Column(Integer, default=0)  # foot-pedal
    frame_material = Column(Integer)
    handlebar_type = Column(Integer)
    frame_size = Column(String(255))
    frame_size_number = Column(Float)
    frame_size_unit = Column(String(255))
    number_of_seats = Column(Integer)

    # Colors
    primary_frame_color_id = Column(Integer, index=True)
    secondary_frame_color_id = Column(Integer, index=True)
    tertiary_frame_color_id = Column(Integer, index=True)
    paint_id = Column(Integer, index=True)

    # Components & Features
    front_wheel_size_id = Column(Integer)
    rear_wheel_size_id = Column(Integer)
    front_gear_type_id = Column(Integer)
    rear_gear_type_id = Column(Integer)
    front_tire_narrow = Column(Boolean)
    rear_tire_narrow = Column(Boolean, default=True)
    belt_drive = Column(Boolean, default=False, nullable=False)
    coaster_brake = Column(Boolean, default=False, nullable=False)

    # Serial & Manufacturing
    made_without_serial = Column(Boolean, default=False, nullable=False)
    extra_registration_number = Column(String(255))
    serial_segments_migrated_at = Column(DateTime)

    # Status & Flags
    status = Column(Integer, default=0, index=True)  # status_with_owner
    example = Column(Boolean, default=False, nullable=False, index=True)
    likely_spam = Column(Boolean, default=False)
    is_for_sale = Column(Boolean, default=False, nullable=False)
    user_hidden = Column(Boolean, default=False, nullable=False, index=True)
    credibility_score = Column(Integer)

    # Location
    latitude = Column(Float, index=True)
    longitude = Column(Float, index=True)
    address_set_manually = Column(Boolean, default=False)
    city = Column(String)
    neighborhood = Column(String)
    street = Column(String)
    zipcode = Column(String(255))
    address_record_id = Column(BigInteger, index=True)
    country_id = Column(Integer)
    state_id = Column(BigInteger, index=True)

    # Media & Documentation
    stock_photo_url = Column(String(255))
    thumb_path = Column(Text)
    pdf = Column(String(255))
    video_embed = Column(Text)

    # Relationships & References
    creator_id = Column(Integer)
    updator_id = Column(Integer)
    creation_organization_id = Column(Integer, index=True)
    current_ownership_id = Column(BigInteger, index=True)
    current_stolen_record_id = Column(Integer, index=True)
    current_impound_record_id = Column(BigInteger, index=True)
    model_audit_id = Column(BigInteger, index=True)
    primary_activity_id = Column(BigInteger, index=True)

    # Metadata
    owner_email = Column(Text)
    cached_data = Column(Text)
    listing_order = Column(Integer, index=True)
    is_phone = Column(Boolean, default=False)
    occurred_at = Column(DateTime)
    updated_by_user_at = Column(DateTime)

    # Soft Delete
    deleted_at = Column(DateTime, index=True)

    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

    # Relationships (to be added)
    # creator = relationship("User", foreign_keys=[creator_id], back_populates="created_bikes")
    # manufacturer = relationship("Manufacturer", back_populates="bikes")
    # stolen_record = relationship("StolenRecord", back_populates="bike")
    # ownerships = relationship("Ownership", back_populates="bike")
