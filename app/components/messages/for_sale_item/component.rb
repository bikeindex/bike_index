# frozen_string_literal: true

module Messages::ForSaleItem
  class Component < ApplicationComponent
    def initialize(result_view: nil, current_user: nil, vehicle: nil, vehicle_id: nil, marketplace_listing: nil)
      @component_class = SearchResults::Container::Component.component_class_for_result_view(result_view || :bike_box)
      @search_kind = :marketplace

      @current_user = current_user
      @vehicle = vehicle
      @vehicle ||= Bike.unscoped.find_by_id(vehicle_id) if vehicle_id.present?
      @marketplace_listing = marketplace_listing
    end

    private

    def search_kind
      :marketplace
    end

    def skip_cache
      true
    end

    def container_class
      SearchResults::Container::Component.container_class(@component_class)
    end
  end
end
