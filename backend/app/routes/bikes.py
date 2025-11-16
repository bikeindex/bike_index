from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from typing import List, Optional
from ..database import get_db
from ..models.bike import Bike
from ..models.user import User
from ..schemas.bike import BikeCreate, BikeUpdate, BikeResponse, BikeSearch
from ..services.auth import get_current_active_user

router = APIRouter()


@router.post("/", response_model=BikeResponse, status_code=status.HTTP_201_CREATED)
def create_bike(
    bike_data: BikeCreate,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Register a new bike"""
    new_bike = Bike(
        **bike_data.dict(),
        creator_id=current_user.id,
        owner_email=current_user.email
    )
    db.add(new_bike)
    db.commit()
    db.refresh(new_bike)
    return new_bike


@router.get("/", response_model=List[BikeResponse])
def list_bikes(
    skip: int = 0,
    limit: int = Query(default=20, le=100),
    stolen: Optional[bool] = None,
    db: Session = Depends(get_db)
):
    """List bikes with optional filters"""
    query = db.query(Bike).filter(Bike.deleted_at.is_(None))

    if stolen is not None:
        if stolen:
            query = query.filter(Bike.status == 1)  # status_stolen
        else:
            query = query.filter(Bike.status == 0)  # status_with_owner

    bikes = query.offset(skip).limit(limit).all()
    return bikes


@router.get("/{bike_id}", response_model=BikeResponse)
def get_bike(bike_id: int, db: Session = Depends(get_db)):
    """Get bike by ID"""
    bike = db.query(Bike).filter(Bike.id == bike_id, Bike.deleted_at.is_(None)).first()
    if not bike:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Bike not found"
        )
    return bike


@router.put("/{bike_id}", response_model=BikeResponse)
def update_bike(
    bike_id: int,
    bike_update: BikeUpdate,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Update bike information"""
    bike = db.query(Bike).filter(Bike.id == bike_id, Bike.deleted_at.is_(None)).first()
    if not bike:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Bike not found"
        )

    # Check ownership (simplified - should check ownerships table)
    if bike.creator_id != current_user.id and not current_user.superuser:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized to update this bike"
        )

    # Update bike fields
    for field, value in bike_update.dict(exclude_unset=True).items():
        setattr(bike, field, value)

    db.commit()
    db.refresh(bike)
    return bike


@router.delete("/{bike_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_bike(
    bike_id: int,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Soft delete a bike"""
    bike = db.query(Bike).filter(Bike.id == bike_id, Bike.deleted_at.is_(None)).first()
    if not bike:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Bike not found"
        )

    # Check ownership
    if bike.creator_id != current_user.id and not current_user.superuser:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized to delete this bike"
        )

    # Soft delete
    from datetime import datetime
    bike.deleted_at = datetime.utcnow()
    db.commit()
