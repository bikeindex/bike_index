# frozen_string_literal: true

module SearchResults::VehicleThumbnail
  class Component < ApplicationComponent
    include BikeHelper

    # current_user is ignored, but included to match other SearchResults components
    def initialize(bike:, current_user: nil, event_record: nil, skip_cache: false, search_kind: nil)
      @bike = bike
      return if @bike.blank?

      @search_kind = SearchResults::Container::Component.permitted_search_kind(search_kind)
      @event_record = event_record || @bike.current_event_record

      @is_cached = !skip_cache
    end

    def render?
      @bike.present?
    end

    private

    def render_status?
      @search_kind != :marketplace && !@bike.status_with_owner?
    end

    def permitted_search_kind(search_kind)
      SearchResults::Container
    end

    def render_for_sale_info?
      @event_record.is_a?(MarketplaceListing)
    end

    def render_event_date?
      @event_record.present? && !@event_record.is_a?(MarketplaceListing)
    end

    def occurred_at_with_fallback
      @bike.occurred_at || @event_record&.updated_at || @bike.updated_at
    end

    def vehicle_image_tag
      thumb_image_url = BikeServices::Displayer.thumb_image_url(@bike)
      if thumb_image_url.present?
        image_tag(thumb_image_url, alt: @bike.title_string, skip_pipeline: true, class: "tw:rounded tw:w-full tw:h-full tw:object-cover")
      else
        image_tag(bike_placeholder_image_path, alt: @bike.title_string, title: "No image",
          class: "tw-block tw:w-full tw:rounded tw:p-8")
      end
    end

    def render_footer?
      address_formatted.present?
    end

    def address_formatted
      @address_formatted ||= if @event_record.is_a?(MarketplaceListing)
        @event_record.formatted_address_string
      else
        @event_record&.address(country: [:iso])
      end
    end
  end
end
