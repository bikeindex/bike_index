# frozen_string_literal: true

module Pages
  module Registrations
    module Show
      module MarketplaceListingCard
        # The for-sale card, styled to match BikeIndexCard
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
            @preview ? @bike.current_marketplace_listing : @bike.current_for_sale_marketplace_listing
          end

          # MessagesController bounces the seller back off their own listing, and
          # takes no message about a draft one
          def show_contact?
            !@owner && !@preview && marketplace_listing.seller_id != @current_user&.id
          end

          def contact_path
            my_account_message_path("ml_#{marketplace_listing.id}")
          end
        end
      end
    end
  end
end
