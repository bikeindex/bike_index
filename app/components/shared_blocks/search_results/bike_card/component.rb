# frozen_string_literal: true

module SharedBlocks
  module SearchResults
    module BikeCard
      # One vehicle in a search's cards view, per the Bike Thumbnails design doc (1c).
      # An organization makes it that org's search - links reach its org pages, and
      # search_all badges whether the bike is registered with it. Without one it's public.
      class Component < ApplicationComponent
        # Template Dependency: Atoms::RegistrationStatusBadge::Component
        include BikeHelper

        # For the list holding them
        LIST_CLASSES = "tw:grid tw:grid-cols-[repeat(auto-fill,minmax(14rem,1fr))] tw:gap-4"

        def initialize(bike:, organization: nil, search_all: false)
          @bike = bike
          @organization = organization
          @search_all = search_all
        end

        private

        # Like the table's rows, not per viewer. The organization record rather than its id,
        # so enabling a feature invalidates; the listing because a price change doesn't
        # touch the bike
        def cache_key
          [self.class.cache_digest, @organization, @search_all, @bike, for_sale_listing]
        end

        def render_org_badge? = @search_all && @organization.present?

        def bike_href = bike_path(@bike, organization_id: @organization&.to_param)

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

        def status_badge(size:)
          Atoms::RegistrationStatusBadge::Component.new(bike: @bike, size:, time: status_time)
        end

        # occurred_at is the stolen or impounded date, and nil for a bike with its owner or
        # for sale. How long a bike has been registered is what vouches for it, so the
        # registration date - not the badge carrying it - is the credibility feature's
        def status_time
          @bike.occurred_at || for_sale_listing&.published_at || (@bike.created_at if credibility_badges?)
        end

        def credibility_badges? = @organization&.enabled?("credibility_badges")

        # Member listings sort ahead of the rest on the marketplace, so the badge says why
        def render_member_badge? = for_sale_listing&.seller_member?

        def location
          @location ||= location_record&.formatted_address_string
        end

        # A bike's own address is its owner's registration address, which only an
        # organization's search may show
        def location_record
          @bike.current_event_record || (@bike if @organization.present?)
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
