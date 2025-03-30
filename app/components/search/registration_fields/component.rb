# frozen_string_literal: true

module Search::RegistrationFields
  class Component < ApplicationComponent
    DEFAULT_DISTANCE = 100
    MAX_DISTANCE = 2_000 # IDK, seems reasonable
    API_COUNT_URL = "/api/v3/search/count"

    def initialize(interpreted_params)
      @distance = if interpreted_params[:distance].present?
        interpreted_params[:distance].to_i
      else
        DEFAULT_DISTANCE
      end
      @distance.clamp(1, MAX_DISTANCE)

      @location = interpreted_params[:location]
      @stolenness = interpreted_params[:stolenness]
      @interpreted_params = interpreted_params # TODO Remove if possible
      @interpreted_params_json = interpreted_params.to_json
    end

    private

    def include_stolenness?
      true # will be false for versions and marketplace
    end

    def location_wrap_hidden?
      @stolenness != "proximity" # also true for marketplace
    end

    def stolenness_options
      # TODO: add Found in search area
      %w[proximity stolen non all]
    end

    def stolenness_li_classes(skip_li_border)
      classes = "tw:w-full tw:has-checked:bg-gray-100 tw:has-checked:dark:bg-gray-700"
      return classes if skip_li_border
      classes + " tw:border-b tw:sm:border-b-0 tw:sm:border-r tw:border-inherit"
    end
  end
end
