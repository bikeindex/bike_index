# Add to a model that can be geolocated
# Expects `latitude` and `longitude` columns to be defined.
module Geocodeable
  extend ActiveSupport::Concern

  module ClassMethods
    def location_attributes
      %w[street city state_id zipcode country_id]
    end
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

    def address_changed?
      %i[street city state_id zipcode country_id]
        .any? { |col| public_send("#{col}_changed?") }
    end

    def address(**kwargs)
      Geocodeable.address(self, **kwargs)
    end
  end

  def address_hash
    attributes.slice("street", "city", "zipcode")
              .merge(state: state&.abbreviation, country: country&.iso)
              .with_indifferent_access
  end

  # Build an address string from the given object's location data.
  #
  # The following keyword args accept booleans for inclusion / omission in the
  # string: `street` `city` `state` `zipcode`, `country`.
  #
  # By default, the country is included as an ISO abbreviation and is required
  # (an empty string is returned if no country is available.)
  #
  # The `country` keyword arg also accepts a list of options to customize
  # output:
  #
  # - :iso or :name for the format
  # - :optional to make the country optional
  # - :skip_default to omit the country name if it's the default country (US)
  #
  # Returns a String.
  def self.address(obj, street: true, city: true, state: true, zipcode: true, country: [:iso])
    return "" if obj.blank?

    include_country =
      country && !(obj.country&.default? && country.include?(:skip_default))

    country_name =
      if include_country
        country_format = country.find { |e| e.in? %i[iso name] } || :iso
        country_name = obj.country&.public_send(country_format)

        country_is_required = !country.include?(:optional)
        not_enough_info = country_is_required && country_name.blank?
        return "" if not_enough_info

        country_name
      end

    [
      street && obj.street,
      city && obj.city,
      [
        state && obj.state&.abbreviation,
        zipcode && obj.zipcode,
      ].reject(&:blank?).join(" "),
      country_name,
    ].reject(&:blank?).join(", ")
  end
end
