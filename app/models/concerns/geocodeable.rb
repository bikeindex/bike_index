# Add to a model that can be geolocated
# Expects `latitude` and `longitude` columns to be defined.
module Geocodeable
  extend ActiveSupport::Concern

  included do
    geocoded_by :geocode_address
    after_validation :geocode, if: :should_be_geocoded?

    attr_accessor :skip_geocoding

    def skip_geocoding?
      !!skip_geocoding
    end

    # Should the receiving object be geocoded?
    #
    # By default:
    #  - we skip geocoding if the `skip_geocoding` flag is set.
    #  - geocode if geocode address is blank or has changed
    #
    # Overwrite in model to customize skip-geocoding logic.
    def should_be_geocoded?
      return false if skip_geocoding?
      geocode_address.blank? || geocode_address_changed?
    end
  end
end
