from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from typing import List, Optional
from ..database import get_db
from ..models.marketplace_listing import MarketplaceListing
from ..models.user import User
from ..schemas.marketplace import (
    MarketplaceListingCreate,
    MarketplaceListingUpdate,
    MarketplaceListingResponse
)
from ..services.auth import get_current_active_user

router = APIRouter()


@router.post("/", response_model=MarketplaceListingResponse, status_code=status.HTTP_201_CREATED)
def create_listing(
    listing_data: MarketplaceListingCreate,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Create a new marketplace listing"""
    new_listing = MarketplaceListing(
        **listing_data.dict(),
        user_id=current_user.id
    )
    db.add(new_listing)
    db.commit()
    db.refresh(new_listing)
    return new_listing


@router.get("/", response_model=List[MarketplaceListingResponse])
def list_listings(
    skip: int = 0,
    limit: int = Query(default=20, le=100),
    active_only: bool = True,
    db: Session = Depends(get_db)
):
    """List marketplace listings"""
    query = db.query(MarketplaceListing).filter(MarketplaceListing.deleted_at.is_(None))

    if active_only:
        query = query.filter(MarketplaceListing.active == True)

    listings = query.order_by(MarketplaceListing.created_at.desc()).offset(skip).limit(limit).all()
    return listings


@router.get("/{listing_id}", response_model=MarketplaceListingResponse)
def get_listing(listing_id: int, db: Session = Depends(get_db)):
    """Get marketplace listing by ID"""
    listing = db.query(MarketplaceListing).filter(
        MarketplaceListing.id == listing_id,
        MarketplaceListing.deleted_at.is_(None)
    ).first()
    if not listing:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Listing not found"
        )
    return listing


@router.put("/{listing_id}", response_model=MarketplaceListingResponse)
def update_listing(
    listing_id: int,
    listing_update: MarketplaceListingUpdate,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Update marketplace listing"""
    listing = db.query(MarketplaceListing).filter(
        MarketplaceListing.id == listing_id,
        MarketplaceListing.deleted_at.is_(None)
    ).first()
    if not listing:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Listing not found"
        )

    # Check ownership
    if listing.user_id != current_user.id and not current_user.superuser:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized to update this listing"
        )

    # Update listing fields
    for field, value in listing_update.dict(exclude_unset=True).items():
        setattr(listing, field, value)

    db.commit()
    db.refresh(listing)
    return listing


@router.delete("/{listing_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_listing(
    listing_id: int,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """Soft delete a marketplace listing"""
    listing = db.query(MarketplaceListing).filter(
        MarketplaceListing.id == listing_id,
        MarketplaceListing.deleted_at.is_(None)
    ).first()
    if not listing:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Listing not found"
        )

    # Check ownership
    if listing.user_id != current_user.id and not current_user.superuser:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized to delete this listing"
        )

    # Soft delete
    from datetime import datetime
    listing.deleted_at = datetime.utcnow()
    db.commit()
