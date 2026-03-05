# frozen_string_literal: true

module Org::BikeSearchRow
  class Component < ApplicationComponent
    def initialize(bike:, organization:, sortable_search_params:,
      bike_sticker: nil, additional_registration_fields: [])
      @bike = bike
      @organization = organization
      @sortable_search_params = sortable_search_params
      @bike_sticker = bike_sticker
      @additional_registration_fields = additional_registration_fields
    end

    private

    # Mark _html translations as html_safe (matching Rails' t() helper behavior)
    def translation(key, **)
      result = super
      key.to_s.end_with?("_html") ? result.html_safe : result
    end
  end
end
