# frozen_string_literal: true

module Org::BikeSearch
  class Component < ApplicationComponent
    def initialize(organization:, bikes:, pagy:, per_page:, params:,
      interpreted_params: {}, sortable_search_params: {},
      search_stickers: nil, search_address: nil, search_status: "all",
      search_query_present: false, time_range: nil, stolenness: "all",
      bike_sticker: nil, model_audit: nil, only_show_bikes: false)
      @organization = organization
      @bikes = bikes
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
      @only_show_bikes = only_show_bikes
    end

    private

    # TODO: Now that we have translations, we need to localize this.
    # I believe the easiest way to do so would be to pull the text from the header cell and use that.
    def column_renames
      @column_renames ||= {
        "created_at_cell" => "Registered",
        "updated_at_cell" => "Updated",
        "stolen_cell" => "Stolen",
        "manufacturer_cell" => "Manufacturer",
        "model_cell" => "Model",
        "color_cell" => "Color",
        "owner_email_cell" => "Sent to",
        "creation_description_cell" => "Source",
        "owner_name_cell" => "Owner name",
        "reg_organization_affiliation_cell" => "Affiliation",
        "reg_extra_registration_number_cell" => "Secondary#",
        "reg_phone_cell" => "Phone",
        "reg_address_cell" => "Address",
        "reg_student_id_cell" => "Student ID",
        "sticker_cell" => "Sticker",
        "impounded_cell" => "Impounded",
        "avery_cell" => "Avery Exportable",
        "cycle_type_cell" => "Vehicle type",
        "propulsion_type_cell" => "E-vehicle (propulsion)",
        "status_cell" => "Status",
        "url_cell" => "URL"
      }
    end

    def additional_registration_fields
      @additional_registration_fields ||= @organization.additional_registration_fields - ["reg_bike_sticker"]
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
        cols += ["avery_cell"] if @organization.enabled?("avery_export")
        cols.uniq.sort { |a, b| column_renames[a] <=> column_renames[b] }
      end
    end

    def settings_default_open?
      @search_stickers.present? || @search_address.present? ||
        @params[:search_impoundedness].present? || Binxtils::InputNormalizer.boolean(@params[:search_open])
    end

    def show_avery_export?
      return @show_avery_export if defined?(@show_avery_export)

      @show_avery_export = @organization.enabled?("avery_export") &&
        Binxtils::InputNormalizer.boolean(@params[:search_avery_export])
    end

    def cycle_type
      @cycle_type ||= begin
        merged = @params.respond_to?(:to_unsafe_h) ? @params.to_unsafe_h.merge(@interpreted_params) : @params.merge(@interpreted_params)
        BikeServices::Displayer.vehicle_search?(merged) ? translation(".vehicle") : translation(".bike")
      end
    end

    def search_params
      @search_params ||= (@sortable_search_params || {}).merge((@interpreted_params || {}).merge(organization_id: @organization.to_param))
    end

    def skip_view_just_stolen?
      @bike_sticker.present?
    end

    def show_search_query_summary?
      @search_query_present || @params[:search_stickers].present? || @params[:search_address].present? || @model_audit.present?
    end

    def show_pagination?
      !@only_show_bikes && @pagy.count > @bikes.count
    end
  end
end
