# frozen_string_literal: true

module Pages
  module Org
    module Search
      module Wrapper
        # A card of org registrations: the match count and the column settings button, the
        # column-visibility panel, the table and the pagination footer. On the registrations
        # search (search_page) the header also carries the view switcher and the export, and
        # the card renders inside the results turbo-frame, so every search brings it back whole.
        class Component < ApplicationComponent
          # Display order, and the first is what search_result_view falls back to
          RESULT_VIEWS = %i[spreadsheet thumbnail].freeze

          def self.permitted_result_view(result_view)
            view = result_view&.to_sym
            RESULT_VIEWS.include?(view) ? view : RESULT_VIEWS.first
          end

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
            bike_sticker: nil,
            model_audit: nil,
            settings: nil,
            result_view: nil,
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
            @bike_sticker = bike_sticker
            @model_audit = model_audit
            @settings = settings
            @result_view = self.class.permitted_result_view(result_view)
            # The search page brings its own Stimulus controllers, and the row of actions
            # across this card's header; everywhere else the card is on its own
            @search_page = search_page
          end

          private

          # Two sentences rather than a count interpolated into one, so a translation can
          # order "over" however it reads. count picks the plural; number is what it renders,
          # which number_display has already marked up
          def count_html
            unless count_stopped?
              return translation(".matching_html", count: @pagy.count, number: number_display(@pagy.count))
            end

            translation(".over_count_matching_html",
              number: number_display(BikeServices::OrganizedSearch::SEARCH_ALL_COUNT_LIMIT))
          end

          def count_stopped?
            @search_all && @pagy.count >= BikeServices::OrganizedSearch::SEARCH_ALL_COUNT_LIMIT
          end

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

          # On the search page the .twwiderow holding the card supplies the gap above it, and
          # is the container twfullbleed reads; elsewhere the card stands on its own
          def card_classes
            ["org-search-component tw:rounded-xl", UI::Card::Component::BASE_CLASSES,
              @search_page ? "tw:twfullbleed" : "tw:mt-4"].join(" ")
          end

          # Built here rather than on the settings struct, which route helpers never reach
          def export_path
            organization_registrations_path(settings.search_params.merge(create_export: true))
          end

          def render_result_view? = Flipper.enabled?(:organization_registration_view_switcher)

          # TODO: the chips move search_result_view through the URL, but nothing renders the
          # thumbnail view behind it yet - see the Bike Thumbnails design doc
          def result_view_entries
            RESULT_VIEWS.map do |view|
              ComponentStructs::Shapes.entry(translation(".view_#{view}"), href: result_view_path(view),
                active: @result_view == view, data: {turbo_action: "advance"})
            end
          end

          def result_view_path(result_view)
            organization_registrations_path(@organization.to_param,
              @sort_state.search_params.except(:organization_id).merge(search_result_view: result_view))
          end

          def show_pagination?
            @pagy.pages > 1
          end

          # The search page declares org--search itself, on a div spanning the form and the
          # chart as well as this card
          def card_data_attributes
            return Pages::Org::Search::ColumnSettings::Component::COLLAPSE_DATA if @search_page

            Pages::Org::Search::ColumnSettings::Component.column_settings_data_attributes(settings, collapse: true)
          end
        end
      end
    end
  end
end
