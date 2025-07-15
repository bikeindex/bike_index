# frozen_string_literal: true

module SearchResults::VehicleThumbnail
  class Component < ApplicationComponent
    include BikeHelper

    def initialize(bike:, current_user: nil, current_event_record: nil, skip_cache: false, search_kind: nil)
      @bike = bike
      return if @bike.blank?

      @search_kind = SearchResults::Container::Component.permitted_search_kind(search_kind)
      @current_event_record ||= @bike.current_event_record

      @is_cached = !skip_cache
      # current_user is ignored, but included to match other SearchResults
    end

    def render?
      @bike.present?
    end

    private

    def permitted_search_kind(search_kind)
      SearchResults::Container
    end

    def render_for_sale_info?
      @bike.is_for_sale? && @current_event_record.is_a?(MarketplaceListing)
    end

    def render_event_date?
      @current_event_record.present? && !@current_event_record.is_a?(MarketplaceListing)
    end

    def occurred_at_with_fallback
      @bike.occurred_at || @current_event_record&.updated_at || @bike.updated_at
    end

    def render_h5?
      render_for_sale_info? || render_event_date?
    end

    def vehicle_image_tag
      thumb_image_url = BikeServices::Displayer.thumb_image_url(@bike)
      if thumb_image_url.present?
        image_tag(thumb_image_url, alt: @bike.title_string, skip_pipeline: true, class: "tw:rounded tw:w-full")
      else
        image_tag(bike_placeholder_image_path, alt: @bike.title_string, title: "No image", class: "tw-block tw:w-full tw:bg-gray-300 tw:dark:bg-gray-800 tw:rounded tw:p-8")
      end
    end
  end
end
