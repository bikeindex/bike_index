# frozen_string_literal: true

module Search::TargetingFields
  class Component < ApplicationComponent
    DEFAULT_DISTANCE = 100
    MAX_DISTANCE = 2_000 # IDK, seems reasonable
    API_COUNT_URL = "/api/v3/search/count"

    def initialize(stolenness:, distance: nil, location: nil)
      @distance = distance.present? ? distance.to_i : DEFAULT_DISTANCE
      @distance.clamp(1, MAX_DISTANCE)

      @location = location
      @stolenness = stolenness
    end

    private

    def include_stolenness?
      true # will be false for versions and marketplace
    end

    def location_fields_hidden?
      @stolenness == "proximity" # also true for marketplace
    end

    def stolenness_options
      # TODO: add Found in search area
      %w[proximity stolen non all]
    end

    def stolenness_no_count
      %w[all]
    end

    def stolenness_li_classes(skip_li_border)
      classes = "tw:w-full tw:has-checked:bg-gray-100 tw:has-checked:dark:bg-gray-700"
      return classes if skip_li_border
      classes + " tw:border-b tw:sm:border-b-0 tw:sm:border-r tw:border-inherit"
    end
  end
end
