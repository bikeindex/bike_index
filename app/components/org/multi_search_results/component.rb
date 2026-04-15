# frozen_string_literal: true

module Org::MultiSearchResults
  class Component < ApplicationComponent
    include SortableHelper

    def initialize(organization:, query:, chip_id:, pagy:, search_kind: "serials",
      bikes: nil, interpreted_params: nil, per_page: nil, close_serials: nil, bike_stickers: nil)
      @organization = organization
      @query = query
      @chip_id = chip_id
      @pagy = pagy
      @search_kind = search_kind
      @bikes = bikes
      @interpreted_params = interpreted_params
      @per_page = per_page
      @close_serials = close_serials
      @bike_stickers = bike_stickers
    end

    private

    def sticker_search?
      @search_kind == "stickers"
    end

    def result_index
      @chip_id&.delete_prefix("chip_")
    end

    def show_view_all?
      @pagy.count > @pagy.limit
    end

    def view_all_path
      if sticker_search?
        helpers.organization_stickers_path(organization_id: @organization.to_param, query: @query)
      else
        helpers.organization_registrations_path(organization_id: @organization.to_param, search_serial: @query)
      end
    end
  end
end
