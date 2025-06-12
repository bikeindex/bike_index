# frozen_string_literal: true

module Search::KindSelectFields
  class Component < ApplicationComponent
    DEFAULT_DISTANCE = 100
    MAX_DISTANCE = 2_000 # IDK, seems reasonable
    API_COUNT_URL = "/api/v3/search/count"

    def initialize(stolenness:, location: nil, distance: nil, is_marketplace: false)
      @is_marketplace = is_marketplace
      @distance = if distance.present?
        distance.to_i
      else
        DEFAULT_DISTANCE
      end
      @distance.clamp(1, MAX_DISTANCE)

      @location = location
      @stolenness = stolenness
    end

    private

    def location_wrap_hidden_class
      return "" if @is_marketplace || @stolenness == "proximity"

      "tw:hidden"
    end

    def include_stolenness?
      true # will be false for versions and marketplace
    end

    def stolenness_options
      # TODO: add Found, Found in search area
      %w[proximity stolen non for_sale all]
    end

    def opt_selected?(opt)
      opt == @stolenness || @is_marketplace && opt == "for_sale"
    end

    def stolenness_li_classes(skip_li_border)
      classes = "tw:w-full tw:has-checked:bg-gray-100 tw:has-checked:dark:bg-gray-800"
      return classes if skip_li_border
      classes + " tw:border-b tw:sm:border-b-0 tw:sm:border-r tw:border-inherit"
    end
  end
end
