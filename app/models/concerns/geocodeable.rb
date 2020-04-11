# Add to a model that can be geolocated
# Expects `latitude` and `longitude` columns to be defined.
module Geocodeable
  extend ActiveSupport::Concern

  def self.bike_location_info?(object)
    object&.country.present? &&
      (object&.city.present? || object&.zipcode.present?)
  end

  included do
    geocoded_by :address
    after_validation :geocode, if: :should_be_geocoded?

    # Skip geocoding if this flag is truthy
    attr_accessor :skip_geocoding

    def skip_geocoding?
      skip_geocoding.present?
    end

    # Should the receiving object be geocoded?
    #
    # By default:
    #  - we skip geocoding if the `skip_geocoding` flag is set.
    #  - geocode if address is present and changed
    #
    # Overwrite this method in inheriting models to customize skip-geocoding
    # logic.
    def should_be_geocoded?
      return false if skip_geocoding?
      return false if address.blank?
      address_changed?
    end

    def bike_location_info?
      Geocodeable.bike_location_info?(self)
    end

    # Proxy method for now, because of the current address setup
    def display_address(skip_default_country: true, force_show_address: false)
      address
    end
  end
end
