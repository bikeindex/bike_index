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
          # The badge vouches for a registration, so it's the credibility feature's
          @render_org_badge = search_all && @organization.present? &&
            @organization.enabled?("credibility_badges")
        end

        private

        # Like the table's rows, not per viewer. The listing and the badge flag are in the
        # key because neither a price change nor enabling the feature touches the bike
        def cache_key
          [self.class.cache_digest, @organization&.id, @render_org_badge, @bike, for_sale_listing]
        end

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

        # occurred_at is the stolen or impounded date, and nil for a bike for sale
        def status_badge
          Atoms::RegistrationStatusBadge::Component.new(bike: @bike, skip_with_owner: true, size: :inherit,
            time: @bike.occurred_at || for_sale_listing&.published_at)
        end

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
