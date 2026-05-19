# frozen_string_literal: true

module Search
  # Backs the search query items combobox (Search::EverythingCombobox::Component):
  # autocomplete options and the selection chips, both rendered for hotwire_combobox.
  class ComboboxController < ApplicationController
    PER_PAGE = 15

    def options
      @search_obj_name = params[:search_obj_name].presence || "Registrations"
      @matches = Autocomplete::Matcher.search(autocomplete_params)
      @next_page = (@matches.length >= per_page) ? current_page + 1 : nil

      render :options
    end

    def chips
      values = params[:combobox_values].to_s.split(",")
      interpreted_params = BikeSearchable.searchable_interpreted_params({query_items: values})
      options = BikeSearchable.selected_query_items_options(interpreted_params)

      chips = options.map do |option|
        display, value = option.is_a?(String) ? [option, option] : [option["text"], option["search_id"]]
        helpers.hw_combobox_selection_chip(display:, value:, for_id: params[:for_id])
      end

      render turbo_stream: helpers.safe_join(chips)
    end

    private

    def autocomplete_params
      params.permit(:q, :page, :per_page, :categories, :cache)
    end

    def per_page
      params[:per_page].presence&.to_i || PER_PAGE
    end

    def current_page
      params[:page].presence&.to_i || 1
    end
  end
end
