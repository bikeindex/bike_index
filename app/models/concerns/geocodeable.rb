# Add to a model that can be geolocated
# Expects `latitude` and `longitude` columns to be defined.
module Geocodeable
  extend ActiveSupport::Concern

  included do
    geocoded_by :address
    before_validation :clean_state_data
    after_validation :bike_index_geocode, if: :should_be_geocoded? # Geocode using our own geocode process

    scope :without_location, -> { where(latitude: nil) }
    scope :with_location, -> { where.not(latitude: nil) }

    # Skip geocoding if this flag is truthy
    attr_accessor :skip_geocoding

    def skip_geocoding?
      skip_geocoding.present?
    end
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
        zipcode && obj.zipcode
      ].reject(&:blank?).join(" "),
      country_name
    ].reject(&:blank?).join(", ")
  end

  def address(**kwargs)
    Geocodeable.address(self, **kwargs)
  end

  def without_location?
    latitude.blank?
  end

  def with_location?
    !without_location?
  end

  # Should the receiving object be geocoded?
  #
  # By default:
  #  - skip geocoding if the `skip_geocoding` flag is set.
  #  - geocode if address is changed
  #
  # Overwrite this method in inheriting models to customize skip-geocoding
  # logic.
  def should_be_geocoded?
    return false if skip_geocoding?
    address_changed?
  end

  def address_changed?
    %i[street city state_id zipcode country_id]
      .any? { |col| public_send("#{col}_changed?") }
  end

  def address_present?
    [street, city, zipcode].any?(&:present?)
  end

  # Separate from bike_index_geocode because some models handle geocoding independently
  def clean_state_data
    # remove state if it's not for the same country - we currently only handle us states
    if country_id.present? && state_id.present?
      self.state_id = nil unless state&.country_id == country_id
    end
  end

  def bike_index_geocode
    # Only geocode if there is specific location information
    self.attributes = if address_present?
      Geohelper.coordinates_for(address) || {}
    else
      {latitude: nil, longitude: nil}
    end
  end

  # default address hash. Probably could be used more often/better
  def address_hash
    attributes.slice("street", "city", "zipcode", "latitude", "longitude")
      .merge(state: state&.abbreviation, country: country&.iso)
      .to_a.map { |k, v| [k, v.blank? ? nil : v] }.to_h # Return blank attrs as nil
      .with_indifferent_access
  end

  # Override assignment to enable friendly finding state and country
  def state=(val)
    return super unless val.is_a?(String)
    self.state = State.fuzzy_find(val)
  end

  def country=(val)
    return super unless val.is_a?(String)
    self.country = Country.fuzzy_find(val)
  end

  def metric_units?
    country.blank? || !country.united_states?
  end
end
