# frozen_string_literal: true

module Org::BikeSearch
  class Component < ApplicationComponent
    include SortableHelper

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
      skip_search_form: false,
      skip_settings: false,
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
      @skip_search_form = skip_search_form
      @skip_settings = skip_settings
      @include_avery = include_avery
    end

    def additional_registration_fields
      @additional_registration_fields ||= @organization.additional_registration_fields - ["reg_bike_sticker"]
    end

    def show_avery_export?
      return @show_avery_export if defined?(@show_avery_export)

      @show_avery_export = @include_avery && @organization.enabled?("avery_export") &&
        Binxtils::InputNormalizer.boolean(@params[:search_avery_export])
    end

    private

    def column_renames
      settings_component.column_renames
    end

    def initially_checked_columns
      settings_component.initially_checked_columns
    end

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
        bike_sticker: @bike_sticker
      )
    end

    def cycle_type
      @cycle_type ||= begin
        merged = @params.merge(@interpreted_params)
        BikeServices::Displayer.vehicle_search?(merged) ? translation(".vehicle") : translation(".bike")
      end
    end

    def active_search_filter_descriptions
      settings_component.active_search_filter_descriptions
    end

    def show_search_query_summary?
      @search_query_present || @params[:search_stickers].present? || @params[:search_address].present? || @model_audit.present?
    end

    def wrapper_data_attributes
      return {} if @skip_settings
      {controller: "org--bike-search",
       "org--bike-search-default-columns-value": initially_checked_columns.to_json}
    end

    def show_pagination?
      @pagy.pages > 1
    end
  end
end
