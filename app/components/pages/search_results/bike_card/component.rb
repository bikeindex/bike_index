# frozen_string_literal: true

module Pages
  module SearchResults
    module BikeCard
      # One vehicle in a search's cards view: the photo carrying its price and status, then
      # title, colors, vehicle type, location and serial. Per the Bike Thumbnails design doc
      # (1c). An organization links each card to its org page, and search_all adds whether
      # the bike is registered with it; without one the card is the public marketplace's.
      class Component < ApplicationComponent
        include BikeHelper

        # For the list holding them
        LIST_CLASSES = "tw:grid tw:grid-cols-[repeat(auto-fill,minmax(14rem,1fr))] tw:gap-4"

        def initialize(bike:, organization: nil, current_user: nil, search_all: false)
          @bike = bike
          @organization = organization
          @current_user = current_user
          @search_all = search_all && @organization.present?
        end

        private

        # Like the table's rows, not per viewer. The listing because a price change doesn't
        # touch the bike
        def cache_key
          [self.class.cache_digest, @organization&.id, @search_all, @bike, for_sale_listing]
        end

        def bike_href
          return @bike.html_url if @organization.blank?

          bike_path(@bike, organization_id: @organization.to_param)
        end

        # The org pages are Turbo's; the public bike page isn't, so it takes a full load
        def bike_link_data
          @organization.present? ? {turbo_frame: "_top"} : {turbo: false}
        end

        def thumb_image_url
          @thumb_image_url ||= BikeServices::Displayer.thumb_image_url(@bike)
        end

        def for_sale_listing
          @for_sale_listing ||= @bike.current_for_sale_marketplace_listing
        end

        # occurred_at is the stolen or impounded date, and nil for a bike with its owner or for sale
        def status_time
          @bike.occurred_at || for_sale_listing&.published_at || @bike.created_at
        end

        def colors
          @colors ||= [@bike.primary_frame_color, @bike.secondary_frame_color, @bike.tertiary_frame_color].compact
        end

        # Member listings sort ahead of the rest on the marketplace, so the badge says why
        def render_member_badge?
          for_sale_listing&.seller_member? || false
        end

        def location
          @location ||= (@bike.current_event_record || @bike).formatted_address_string
        end

        # Lazily, so a cached card doesn't query it
        def organized?
          return @organized if defined?(@organized)

          @organized = @bike.organized?(@organization)
        end

        def org_badge_text
          return translation(".registered_with", org_name: @organization.short_name) if organized?

          translation(".not_registered_with", org_name: @organization.short_name)
        end
      end
    end
  end
end
