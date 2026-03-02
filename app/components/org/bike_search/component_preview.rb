# frozen_string_literal: true

module Org::BikeSearch
  class ComponentPreview < ApplicationComponentPreview
    def default
      render(Org::BikeSearch::Component.new(organization:, bikes:, pagy:, interpreted_params:, sortable_search_params:, per_page:, params:, search_stickers:, search_address:, search_status:, search_query_present:, time_range:, stolenness:, bike_sticker:, model_audit:, only_show_bikes:))
    end
  end
end
