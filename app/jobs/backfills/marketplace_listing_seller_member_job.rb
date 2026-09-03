# frozen_string_literal: true

module Backfills
  # Populate seller_member, which its migration defaulted to false. A listing tracks
  # the seller's membership while it's current and freezes that value once sold/removed:
  #   - current listings     -> whether the seller is a member now
  #   - non-current listings -> whether the seller was a member when the listing ended
  class MarketplaceListingSellerMemberJob < ApplicationJob
    sidekiq_options queue: "low_priority", retry: false

    def perform
      MarketplaceListing.includes(:seller).find_each do |listing|
        seller_member = calculated_seller_member(listing)
        next if listing.seller_member == seller_member

        listing.update_column(:seller_member, seller_member)
        # Bump the bike so its cached search-result fragment (the badge) re-renders
        listing.item&.update_column(:updated_at, Time.current) if listing.current?
      end
    end

    private

    def calculated_seller_member(listing)
      seller = listing.seller
      return false if seller.blank?
      return seller.member? if listing.current?

      seller.memberships.period_active_at(listing.end_at || listing.updated_at).any?
    end
  end
end
