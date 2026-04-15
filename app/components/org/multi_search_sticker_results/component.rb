# frozen_string_literal: true

module Org::MultiSearchStickerResults
  class Component < ApplicationComponent
    def initialize(organization:, query:, query_chip_id:, pagy:, bike_stickers:)
      @organization = organization
      @query = query
      @query_chip_id = query_chip_id
      @pagy = pagy
      @bike_stickers = bike_stickers
    end

    private

    def result_index
      @query_chip_id&.delete_prefix("chip_")
    end

    def show_view_all?
      @pagy.count > @pagy.limit
    end

    def view_all_path
      helpers.organization_stickers_path(organization_id: @organization.to_param, query: @query)
    end
  end
end
