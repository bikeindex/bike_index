# frozen_string_literal: true

module Org::RegistrationSearch
  class Component < ApplicationComponent
    include SortableHelper

    delegate :additional_registration_fields, :column_renames,
      :initially_checked_columns, :cycle_type, :active_search_filter_descriptions,
      to: :settings_component
    def initialize(
      organization:,
      pagy:,
      per_page:,
      params:,
      bikes: [],
      current_user: nil,
      interpreted_params: {},
      sortable_search_params: {},
      search_stickers: nil,
      search_address: nil,
      search_status: "all",
      search_query_present: false,
      time_range: nil,
      stolenness: "all",
      bike_sticker: nil,
      model_audit: nil,
      skip_search_and_filters: false,
      skip_settings: false
    )
      @organization = organization
      @pagy = pagy
      @bikes = bikes
      @current_user = current_user
      @interpreted_params = interpreted_params
      @sortable_search_params = sortable_search_params
      @per_page = per_page
      @params = params
      @search_stickers = search_stickers
      @search_address = search_address
      @search_status = search_status
      @search_query_present = search_query_present
      @time_range = time_range
      @stolenness = stolenness
      @bike_sticker = bike_sticker
      @model_audit = model_audit
      @skip_search_and_filters = skip_search_and_filters
      @skip_settings = skip_settings
    end

    private

    def settings_component
      @settings_component ||= Org::RegistrationSearchSettings::Component.new(
        organization: @organization,
        interpreted_params: @interpreted_params,
        sortable_search_params: @sortable_search_params,
        params: @params,
        search_stickers: @search_stickers,
        search_address: @search_address,
        search_status: @search_status,
        bike_sticker: @bike_sticker,
        skip_search_and_filters: @skip_search_and_filters
      )
    end

    def show_search_query_summary?
      @search_query_present || @params[:search_stickers].present? || @params[:search_address].present? || @model_audit.present?
    end

    def component_wrapper_data_attributes
      return {} if @skip_settings
      {controller: "org--registration-search org--registration-search-column-toggle",
       "org--registration-search-column-toggle-default-columns-value": initially_checked_columns.to_json}
    end

    def table_wrapper_data_attributes
      attrs = {
        controller: "update-cached-sortable-links org--assign-bike-sticker",
        "update-cached-sortable-links-base-url-value": url_for(@sortable_search_params.merge(organization_id: @organization.to_param))
      }
      if @bike_sticker.present?
        attrs[:"org--assign-bike-sticker-sticker-path-value"] = bike_sticker_path(id: @bike_sticker.code, organization_id: @bike_sticker.organization_id)
      end
      attrs
    end

    def show_pagination?
      @pagy.pages > 1
    end
  end
end
