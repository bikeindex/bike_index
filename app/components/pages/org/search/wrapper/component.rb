# frozen_string_literal: true

module Pages
  module Org
    module Search
      module Wrapper
        class Component < ApplicationComponent
          delegate :cycle_type, :active_search_filter_descriptions, to: :settings

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
            search_query_present: false,
            humanized_time_range: nil,
            stolenness: "all",
            bike_sticker: nil,
            model_audit: nil,
            skip_search_and_filters: false,
            skip_settings: false,
            skip_count: false
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
            @search_query_present = search_query_present
            @humanized_time_range = humanized_time_range
            @stolenness = stolenness
            @bike_sticker = bike_sticker
            @model_audit = model_audit
            @skip_search_and_filters = skip_search_and_filters
            @skip_settings = skip_settings
            @skip_count = skip_count
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
              search_status: @search_status
            )
          end

          def settings_component
            @settings_component ||= Pages::Org::Search::Settings::Component
              .new(settings:, skip_search_and_filters: @skip_search_and_filters)
          end

          def show_search_query_summary?
            @search_query_present || @params[:search_stickers].present? || @params[:search_address].present? || @model_audit.present?
          end

          def component_wrapper_data_attributes
            @skip_settings ? {} : settings.column_toggle_data_attributes
          end

          def show_pagination?
            @pagy.pages > 1
          end
        end
      end
    end
  end
end
