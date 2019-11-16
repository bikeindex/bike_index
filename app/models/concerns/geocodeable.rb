# Add to a model that can be geolocated
# Expects `latitude` and `longitude` columns to be defined.
module Geocodeable
  extend ActiveSupport::Concern

  included do
    geocoded_by :geocode_data
    after_validation :geocode, if: :should_be_geocoded?

    attr_accessor :skip_geocoding

    def skip_geocoding?
      !!skip_geocoding
    end

    # Customize by overwriting in the Geocodeable model.
    def geocode_data
      @geocode_data ||= address
    end

    # An array of symbols of the db columns upon which `geocode_data`
    # depends.These are checked for changes before geocoding using
    # `should_be_geocoded?`. By default, empty, so we don't check for changes.
    def geocode_columns; []; end

    def any_geocode_columns_changed?
      return true if geocode_columns.blank?
      geocode_columns.any? { |col| public_send("#{col}_changed?") }
    end

    # Overwrite in model to customize skip-geocoding logic.
    def should_be_geocoded?
      return false if skip_geocoding?
      geocode_data.present? && any_geocode_columns_changed?
    end
  end
end
