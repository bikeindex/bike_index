# frozen_string_literal: true

module Org::RegistrationSearchSettings
  class Component < ApplicationComponent
    COLUMN_RENAME_KEYS = %i[
      created_at_cell
      updated_at_cell
      stolen_cell
      serial_number_cell
      manufacturer_cell
      model_cell
      color_cell
      owner_email_cell
      creation_description_cell
      owner_name_cell
      reg_organization_affiliation_cell
      reg_extra_registration_number_cell
      reg_phone_cell
      reg_address_cell
      reg_student_id_cell
      notes_cell
      sticker_cell
      impound_id_cell
      impounded_cell
      avery_cell
      cycle_type_cell
      propulsion_type_cell
      status_cell
      url_cell
    ].freeze

    ORG_PREFIXED_COLUMNS = %i[reg_organization_affiliation_cell reg_student_id_cell notes_cell].freeze

    FILTER_DESCRIPTION_KEYS = {
      search_stickers: {with: ".filter_with_stickers_html", none: ".filter_no_sticker_html"},
      search_address: {with_street: ".filter_with_address_html", without_street: ".filter_no_address_html"},
      search_status: {not_impounded: ".filter_not_impounded_html", impounded: ".filter_impounded_html",
                      with_owner: ".filter_not_stolen_or_impounded_html", stolen: ".filter_stolen_html"}
    }.freeze

    attr_reader :organization

    def initialize(
      organization:,
      interpreted_params: {},
      sortable_search_params: {},
      params: {},
      search_stickers: nil,
      search_address: nil,
      search_status: "all",
      bike_sticker: nil,
      skip_search_and_filters: false
    )
      @organization = organization
      @interpreted_params = interpreted_params
      @sortable_search_params = sortable_search_params
      @params = params
      @search_stickers = search_stickers
      @search_address = search_address
      @search_status = search_status
      @bike_sticker = bike_sticker
      @skip_search_and_filters = skip_search_and_filters
    end

    # Called via delegation from Org::RegistrationSearch
    def active_search_filter_descriptions
      values = {search_stickers: @search_stickers, search_address: @search_address, search_status: @search_status}

      FILTER_DESCRIPTION_KEYS.filter_map do |param, mapping|
        value = values[param]
        key = mapping[value.to_sym] if value.is_a?(String)
        translation(key) if key
      end
    end

    def initially_checked_columns
      @initially_checked_columns ||= begin
        cols = %w[created_at_cell stolen_cell manufacturer_cell model_cell
          color_cell owner_email_cell owner_name_cell creation_description_cell]
        cols += ["sticker_cell"] if @organization.enabled?("bike_stickers")
        cols += ["impounded_cell"] if @params[:search_impoundedness] == "impounded"
        cols
      end
    end

    def column_renames
      @column_renames ||= COLUMN_RENAME_KEYS.map { |key|
        name = translation(".#{key}")
        name = "#{@organization.short_name} #{name}" if ORG_PREFIXED_COLUMNS.include?(key)
        [key, name]
      }.to_h
    end

    def additional_registration_fields
      @additional_registration_fields ||= @organization.additional_registration_fields - ["reg_bike_sticker"]
    end

    def cycle_type
      @cycle_type ||= begin
        merged = @params.merge(@interpreted_params)
        BikeServices::Displayer.vehicle_search?(merged) ? translation(".vehicle") : translation(".bike")
      end
    end

    private

    def enabled_columns
      @enabled_columns ||= begin
        cols = initially_checked_columns.dup
        cols += %w[url_cell updated_at_cell serial_number_cell cycle_type_cell propulsion_type_cell status_cell]
        cols += additional_registration_fields.map { |f| "#{f}_cell" }
        cols += ["notes_cell"] if @organization.enabled?("registration_notes")
        cols += %w[impound_id_cell impounded_cell] if @organization.enabled?("impound_bikes")
        cols += ["avery_cell"] if @organization.enabled?("avery_export")
        cols.uniq.sort { |a, b| column_renames[a.to_sym] <=> column_renames[b.to_sym] }
      end
    end

    def settings_default_open?
      @search_stickers.present? || @search_address.present? ||
        @params[:search_impoundedness].present? || Binxtils::InputNormalizer.boolean(@params[:search_open])
    end

    def search_params
      @search_params ||= (@sortable_search_params || {}).merge((@interpreted_params || {}).merge(organization_id: @organization.to_param))
    end
  end
end
