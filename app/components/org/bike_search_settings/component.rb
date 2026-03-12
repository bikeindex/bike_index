# frozen_string_literal: true

module Org::BikeSearchSettings
  class Component < ApplicationComponent
    def initialize(
      organization:,
      interpreted_params: {},
      sortable_search_params: {},
      params: {},
      search_stickers: nil,
      search_address: nil,
      search_status: "all",
      include_avery: false,
      bike_sticker: nil
    )
      @organization = organization
      @interpreted_params = interpreted_params
      @sortable_search_params = sortable_search_params
      @params = params
      @search_stickers = search_stickers
      @search_address = search_address
      @search_status = search_status
      @include_avery = include_avery
      @bike_sticker = bike_sticker
    end

    def initially_checked_columns
      @initially_checked_columns ||= begin
        cols = %w[created_at_cell stolen_cell manufacturer_cell model_cell
          color_cell owner_email_cell owner_name_cell creation_description_cell]
        cols += ["sticker_cell"] if @organization.enabled?("bike_stickers")
        cols += ["avery_cell"] if show_avery_export?
        cols += ["impounded_cell"] if @params[:search_impoundedness] == "impounded"
        cols
      end
    end

    def show_avery_export?
      return @show_avery_export if defined?(@show_avery_export)

      @show_avery_export = @include_avery && @organization.enabled?("avery_export") &&
        Binxtils::InputNormalizer.boolean(@params[:search_avery_export])
    end

    private

    def column_renames
      Org::BikeSearch::Component.column_renames
    end

    def additional_registration_fields
      @additional_registration_fields ||= @organization.additional_registration_fields - ["reg_bike_sticker"]
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
  end
end
