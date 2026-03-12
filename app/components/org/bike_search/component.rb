# frozen_string_literal: true

module Org::BikeSearch
  class Component < ApplicationComponent
    include SortableHelper

    COLUMN_RENAME_KEYS = {
      created_at_cell: ".registered",
      updated_at_cell: ".updated",
      stolen_cell: ".stolen",
      manufacturer_cell: ".manufacturer",
      model_cell: ".model",
      color_cell: ".color",
      owner_email_cell: ".sent_to",
      creation_description_cell: ".source",
      owner_name_cell: ".owner_name",
      reg_organization_affiliation_cell: ".affiliation",
      reg_extra_registration_number_cell: ".secondary_number",
      reg_phone_cell: ".phone",
      reg_address_cell: ".reg_address",
      reg_student_id_cell: ".student_id",
      sticker_cell: ".sticker",
      impounded_cell: ".impounded",
      avery_cell: ".avery_exportable",
      cycle_type_cell: ".vehicle_type",
      propulsion_type_cell: ".e_vehicle_propulsion",
      status_cell: ".status_cell",
      url_cell: ".url"
    }.freeze

    def self.column_renames
      COLUMN_RENAME_KEYS.transform_values { |key| I18n.t("components.org.bike_search#{key}") }
    end

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
      self.class.column_renames
    end

    def initially_checked_columns
      return @initially_checked_columns if defined?(@initially_checked_columns)

      @initially_checked_columns = %w[created_at_cell stolen_cell manufacturer_cell model_cell
        color_cell owner_email_cell owner_name_cell creation_description_cell]
      @initially_checked_columns += ["sticker_cell"] if @organization.enabled?("bike_stickers")
      @initially_checked_columns += ["avery_cell"] if show_avery_export?
      @initially_checked_columns += ["impounded_cell"] if @params[:search_impoundedness] == "impounded"
      @initially_checked_columns
    end

    def enabled_columns
      @enabled_columns ||= begin
        cols = initially_checked_columns.dup
        cols += %w[url_cell updated_at_cell cycle_type_cell propulsion_type_cell status_cell]
        cols += additional_registration_fields.map { |f| "#{f}_cell" }
        cols += ["impounded_cell"] if @organization.enabled?("impound_bikes")
        cols += ["avery_cell"] if @include_avery && @organization.enabled?("avery_export")
        cols.uniq.sort { |a, b| column_renames[a.to_sym] <=> column_renames[b.to_sym] }
      end
    end

    def settings_default_open?
      @search_stickers.present? || @search_address.present? ||
        @params[:search_impoundedness].present? || Binxtils::InputNormalizer.boolean(@params[:search_open])
    end

    def cycle_type
      @cycle_type ||= begin
        merged = @params.merge(@interpreted_params)
        BikeServices::Displayer.vehicle_search?(merged) ? translation(".vehicle") : translation(".bike")
      end
    end

    def search_params
      @search_params ||= (@sortable_search_params || {}).merge((@interpreted_params || {}).merge(organization_id: @organization.to_param))
    end

    def active_search_filter_descriptions
      @active_search_filter_descriptions ||= [].tap do |descriptions|
        case @search_stickers
        when "with" then descriptions << translation(".filter_with_stickers_html")
        when "none" then descriptions << translation(".filter_no_sticker_html")
        end
        case @search_address
        when "with_street" then descriptions << translation(".filter_with_address_html")
        when "without_street" then descriptions << translation(".filter_no_address_html")
        end
        if @params[:search_status].present?
          case @search_status
          when "not_impounded" then descriptions << translation(".filter_not_impounded_html")
          when "impounded" then descriptions << translation(".filter_impounded_html")
          when "with_owner" then descriptions << translation(".filter_not_stolen_or_impounded_html")
          when "stolen" then descriptions << translation(".filter_stolen_html")
          end
        end
      end
    end

    def show_search_query_summary?
      @search_query_present || @params[:search_stickers].present? || @params[:search_address].present? || @model_audit.present?
    end

    def show_pagination?
      @pagy.pages > 1
    end
  end
end
