# frozen_string_literal: true

module Pages
  module Org
    module SearchResults
      module BikeCard
        # One registration in the org search's thumbnail view: the photo carrying its price and
        # status, then title, colors, vehicle type, location and serial. Per the Bike Thumbnails
        # design doc (1c). search_all adds whether it's registered with the organization.
        class Component < ApplicationComponent
          include BikeHelper

          def initialize(bike:, organization:, current_user: nil, search_all: false)
            @bike = bike
            @organization = organization
            @current_user = current_user
            @search_all = search_all
          end

          private

          # Like the spreadsheet's rows, not per viewer. The listing because a price change doesn't
          # touch the bike
          def cache_key
            [self.class.cache_digest, @organization.id, @search_all, @bike, for_sale_listing]
          end

          def bike_path_for_org
            bike_path(@bike, organization_id: @organization.to_param)
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
end
