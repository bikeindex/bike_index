# frozen_string_literal: true

module Search
  # Backs the comboboxes that autocomplete from the Autocomplete index: the search
  # query items (Pages::Search::EverythingCombobox::Component) - options and selection chips -
  # and the manufacturer picker (UI::Forms::ComboboxManufacturer::Component).
  class ComboboxController < ApplicationController
    PER_PAGE = 15

    # Every action only ever renders turbo_stream
    before_action { request.format = :turbo_stream }

    def options
      matches = Autocomplete::Matcher.search(autocomplete_params)

      render(
        Pages::Search::EverythingComboboxOptions::Component.new(
          matches:,
          search_obj_name: params[:search_obj_name].presence || "Registrations",
          next_page: next_page_for(matches),
          first_page: helpers.hw_first_page?,
          q: params[:q]
        )
      )
    end

    def manufacturers
      matches = Autocomplete::Matcher.search(manufacturer_params)

      render(
        UI::Forms::ComboboxManufacturerOptions::Component.new(
          matches:,
          next_page: next_page_for(matches),
          first_page: helpers.hw_first_page?,
          q: params[:q],
          no_manufacturer_other: Binxtils::InputNormalizer.boolean(params[:no_manufacturer_other])
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

    # frame_maker limits the categories to manufacturers that make frames
    def manufacturer_params
      categories = Binxtils::InputNormalizer.boolean(params[:frame_maker]) ? %w[frame_mnfg] : %w[cmp_mnfg frame_mnfg]

      autocomplete_params.merge(categories:)
    end

    def next_page_for(matches)
      (matches.length >= PER_PAGE) ? current_page + 1 : nil
    end

    def current_page
      params[:page].presence&.to_i || 1
    end
  end
end
