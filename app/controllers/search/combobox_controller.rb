# frozen_string_literal: true

module Search
  # Backs the search query items combobox (Search::EverythingCombobox::Component):
  # autocomplete options and the selection chips, both rendered for hotwire_combobox.
  class ComboboxController < ApplicationController
    PER_PAGE = 15

    # Both actions only ever render turbo_stream (the hotwire_combobox partials
    # exist solely in that format). Clients that drop the format param - e.g. a
    # crawler following the pagination src with HTML-encoded "&amp;format=..." -
    # would otherwise default to :html and raise ActionView::MissingTemplate.
    before_action { request.format = :turbo_stream }

    def options
      matches = Autocomplete::Matcher.search(autocomplete_params)
      next_page = (matches.length >= PER_PAGE) ? current_page + 1 : nil

      render turbo_stream: view_context.render(
        Search::EverythingComboboxOptions::Component.new(
          matches:,
          search_obj_name: params[:search_obj_name].presence || "Registrations",
          next_page:,
          q: params[:q]
        )
      )
    end

    def chips
      values = params[:combobox_values].to_s.split(",")
      interpreted_params = BikeSearchable.searchable_interpreted_params({query_items: values})
      options = BikeSearchable.selected_query_items_options(interpreted_params)

      chips = options.map do |option|
        display, value = BikeSearchable.query_item_display_value(option)
        helpers.hw_combobox_selection_chip(display:, value:, for_id: params[:for_id])
      end

      render turbo_stream: helpers.safe_join(chips)
    end

    private

    def autocomplete_params
      params.permit(:q, :page, :categories, :cache).merge(per_page: PER_PAGE)
    end

    def current_page
      params[:page].presence&.to_i || 1
    end
  end
end
