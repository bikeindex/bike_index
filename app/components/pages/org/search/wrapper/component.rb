# frozen_string_literal: true

module Pages
  module Org
    module Search
      module Wrapper
        # A card of org registrations: the match count, the column-visibility panel, the
        # table and the pagination footer. On the registrations search (search_page) it also
        # carries the row of actions across the top, and renders inside the results
        # turbo-frame, so every search brings the whole card back.
        class Component < ApplicationComponent
          def initialize(
            organization:,
            pagy:,
            per_page:,
            params:,
            bikes: [],
            current_user: nil,
            interpreted_params: {},
            sort_state: ComponentStructs::SortState.new,
            search_stickers: nil,
            search_address: nil,
            search_status: "all",
            search_unregisteredness: nil,
            search_all: false,
            humanized_time_range: nil,
            bike_sticker: nil,
            model_audit: nil,
            settings: nil,
            search_page: false
          )
            @organization = organization
            @pagy = pagy
            @bikes = bikes
            @current_user = current_user
            @interpreted_params = interpreted_params
            @sort_state = sort_state
            @per_page = per_page
            @params = params
            @search_stickers = search_stickers
            @search_address = search_address
            @search_status = search_status
            @search_unregisteredness = search_unregisteredness
            @search_all = search_all
            @humanized_time_range = humanized_time_range
            @bike_sticker = bike_sticker
            @model_audit = model_audit
            @settings = settings
            # The search page brings its own Stimulus controllers and opens the column panel
            # from this card's header; everywhere else the card is on its own
            @search_page = search_page
          end

          private

          def settings
            @settings ||= ComponentStructs::OrgSearchSettings.new(
              organization: @organization,
              interpreted_params: @interpreted_params,
              sortable_search_params: @sort_state.search_params,
              params: @params,
              search_stickers: @search_stickers,
              search_address: @search_address,
              search_status: @search_status,
              search_unregisteredness: @search_unregisteredness,
              search_all: @search_all
            )
          end

          def settings_component
            @settings_component ||= Pages::Org::Search::Settings::Component
              .new(settings:, toggle_button: !@search_page)
          end

          # On the search page the .twwiderow holding the card supplies the gap above it, and
          # is the container twfullbleed reads; elsewhere the card stands on its own
          def card_classes
            ["org-search-component tw:overflow-hidden tw:rounded-xl", UI::Card::Component::BASE_CLASSES,
              @search_page ? "tw:twfullbleed" : "tw:mt-4"].join(" ")
          end

          # Built here rather than on the settings struct, which route helpers never reach
          def export_path
            organization_registrations_path(settings.search_params.merge(create_export: true))
          end

          # TODO: the thumbnail chip is inert until the view behind it exists - see the
          # Bike Thumbnails design doc
          def result_view_entries
            [ComponentStructs::Shapes.entry(translation(".view_spreadsheet"), active: true),
              ComponentStructs::Shapes.entry(translation(".view_thumbnail"))]
          end

          def show_pagination?
            @pagy.pages > 1
          end

          # The search page declares org--search itself, on a div spanning the form and the
          # chart as well as this card
          def card_data_attributes
            collapse = Pages::Org::Search::Settings::Component::COLLAPSE_DATA
            return collapse if @search_page

            Pages::Org::Search::Settings::Component
              .column_toggle_data_attributes(settings, controllers: collapse[:controller])
              .merge(collapse.except(:controller))
          end
        end
      end
    end
  end
end
