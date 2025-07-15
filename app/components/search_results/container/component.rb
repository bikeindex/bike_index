# frozen_string_literal: true

module SearchResults::Container
  class Component < ApplicationComponent
    LI_KINDS_COMPONENTS = {
      bike_box: SearchResults::BikeBox::Component,
      thumbnail: SearchResults::VehicleThumbnail::Component
    }.freeze
    SEARCH_KINDS = %i[registration marketplace].freeze

    def self.permitted_search_kind(search_kind = nil)
      kind_sym = search_kind&.to_sym
      SEARCH_KINDS.include?(kind_sym) ? kind_sym : SEARCH_KINDS.first
    end

    def initialize(li_kind:, search_kind:, current_user: nil, vehicles: nil, skip_cache: false)
      @component_class = component_class_for_li_kind(li_kind)
      @search_kind = self.class.permitted_search_kind(search_kind)

      @current_user = current_user
      @vehicles = vehicles
      @skip_cache = skip_cache
    end

    def render?
      @vehicles.present? || content.present?
    end

    private

    def component_class_for_li_kind(li_kind)
      kind_sym = li_kind&.to_sym
      if LI_KINDS_COMPONENTS.key?(kind_sym)
        LI_KINDS_COMPONENTS[kind_sym]
      else
        LI_KINDS_COMPONENTS.values.first
      end
    end

    def container_class
      if @component_class == SearchResults::VehicleThumbnail::Component
        "tw:grid tw:gap-x-3 tw:gap-y-6 tw:grid-cols-[repeat(auto-fit,minmax(16rem,1fr))]"
      else
        "bike-boxes"
      end
    end
  end
end
