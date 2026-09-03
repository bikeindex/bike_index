# frozen_string_literal: true

module Pages
  module Registrations
    module Show
      module MarketplaceListing
        # The for-sale card, matching BikeIndexCard's styling. The caller passes
        # the definition-list term to control the layout.
        class Component < ApplicationComponent
          # preview: render the seller's draft listing as the public will see it
          def initialize(bike:, term:, current_user: nil, owner: false, preview: false)
            @bike = bike
            @term = term
            @current_user = current_user
            @owner = owner
            @preview = preview
          end

          def render?
            marketplace_listing.present?
          end

          private

          def marketplace_listing
            return @marketplace_listing if defined?(@marketplace_listing)

            @marketplace_listing = if @preview
              @bike.current_marketplace_listing
            else
              @bike.current_for_sale_marketplace_listing
            end
          end

          # MessagesController bounces the seller back off their own listing, and
          # takes no message about a draft one
          def show_contact?
            !@owner && !@preview && marketplace_listing.seller_id != @current_user&.id
          end

          def contact_path
            my_account_message_path("ml_#{marketplace_listing.id}")
          end

          # Only meaningful once it's a day past the listing going up
          def still_for_sale_if_show
            still_for_sale_at = marketplace_listing.still_for_sale_at
            return if still_for_sale_at.blank? || marketplace_listing.published_at.blank? ||
              still_for_sale_at < (marketplace_listing.published_at + 1.day)

            still_for_sale_at
          end
        end
      end
    end
  end
end
