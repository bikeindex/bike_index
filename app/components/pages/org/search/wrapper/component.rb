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
          delegate :initially_checked_columns, :cycle_type, :active_search_filter_descriptions,
            :render_export?, to: :settings_component

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
            search_parking_notification: nil,
            search_query_present: false,
            search_all: false,
            humanized_time_range: nil,
            stolenness: "all",
            bike_sticker: nil,
            model_audit: nil,
            skip_count: false,
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
            @search_parking_notification = search_parking_notification
            @search_query_present = search_query_present
            @search_all = search_all
            @humanized_time_range = humanized_time_range
            @stolenness = stolenness
            @bike_sticker = bike_sticker
            @model_audit = model_audit
            @skip_count = skip_count
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
              search_parking_notification: @search_parking_notification,
              bike_sticker: @bike_sticker,
              search_all: @search_all,
              toggle_button: !@search_page
            )
          end

          # search_all is in here because the other sentence names the organization, which a
          # search reaching past its own registrations isn't limited to
          def show_search_query_summary?
            @search_query_present || @search_all || @params[:search_stickers].present? ||
              @params[:search_address].present? || @model_audit.present?
          end

          # Built here rather than on the settings component, which route helpers can't reach
          # until it's rendered itself
          def export_path
            organization_registrations_path(settings_component.search_params.merge(create_export: true))
          end

          def add_bike_path
            new_organization_registration_path(@organization.to_param)
          end

          def result_view_entries
            [ComponentStructs::Shapes.entry(translation(".view_spreadsheet"), active: true),
              ComponentStructs::Shapes.entry(translation(".view_thumbnail"), disabled: true)]
          end

          def show_pagination?
            @pagy.pages > 1
          end

          def card_data_attributes
            @search_page ? {} : settings_component.column_toggle_data_attributes
          end
        end
      end
    end
  end
end
