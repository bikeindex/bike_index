# frozen_string_literal: true

module Org::BikeSearch
  class Component < ApplicationComponent
    include SortableHelper

    delegate :additional_registration_fields, :show_avery_export?, :column_renames,
      :initially_checked_columns, :cycle_type, :active_search_filter_descriptions,
      to: :settings_component
    def initialize(
      organization:,
      pagy:,
      per_page:,
      params:,
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
      include_avery: false
    )
      @organization = organization
      @pagy = pagy
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
      @include_avery = include_avery
    end

    private

    def settings_component
      @settings_component ||= Org::BikeSearchSettings::Component.new(
        organization: @organization,
        interpreted_params: @interpreted_params,
        sortable_search_params: @sortable_search_params,
        params: @params,
        search_stickers: @search_stickers,
        search_address: @search_address,
        search_status: @search_status,
        include_avery: @include_avery,
        bike_sticker: @bike_sticker,
        skip_search_and_filters: @skip_search_and_filters
      )
    end

    def show_search_query_summary?
      @search_query_present || @params[:search_stickers].present? || @params[:search_address].present? || @model_audit.present?
    end

    def wrapper_data_attributes
      return {} if @skip_search_and_filters
      {controller: "org--bike-search",
       "org--bike-search-default-columns-value": initially_checked_columns.to_json}
    end

    def show_pagination?
      @pagy.pages > 1
    end
  end
end
