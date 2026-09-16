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
          delegate :initially_checked_columns, :cycle_type, to: :settings_component

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
            search_parking_notification: nil,
            search_all: false,
            humanized_time_range: nil,
            bike_sticker: nil,
            model_audit: nil,
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
            @search_parking_notification = search_parking_notification
            @search_all = search_all
            @humanized_time_range = humanized_time_range
            @bike_sticker = bike_sticker
            @model_audit = model_audit
            # The search page brings its own Stimulus controllers and opens the column panel
            # from this card's header; everywhere else the card is on its own
            @search_page = search_page
          end

          private

          def settings_component
            @settings_component ||= Pages::Org::Search::Settings::Component.new(
              organization: @organization,
              interpreted_params: @interpreted_params,
              sortable_search_params: @sort_state.search_params,
              params: @params,
              search_stickers: @search_stickers,
              search_address: @search_address,
              search_status: @search_status,
              search_unregisteredness: @search_unregisteredness,
              search_parking_notification: @search_parking_notification,
              bike_sticker: @bike_sticker,
              search_all: @search_all,
              toggle_button: !@search_page
            )
          end

          def add_bike_path
            new_organization_registration_path(@organization.to_param)
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
            collapse = {controller: "ui--collapse", "ui--collapse-storage-key-value": "orgRegistrationColumnsOpen"}
            return collapse if @search_page

            attributes = settings_component.column_toggle_data_attributes
            attributes.merge(collapse) { |_key, mine, theirs| "#{mine} #{theirs}" }
          end
        end
      end
    end
  end
end
