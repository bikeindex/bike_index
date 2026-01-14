# frozen_string_literal: true

# TODO: show deleted and sold items info

module Messages::ForSaleItem
  class Component < ApplicationComponent
    def initialize(result_view: :bike_box, current_user: nil, vehicle: nil, vehicle_id: nil)
      @component_class = SearchResults::Container::Component.component_class_for_result_view(result_view)
      @search_kind = :marketplace

      @current_user = current_user
      @vehicle = vehicle
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
