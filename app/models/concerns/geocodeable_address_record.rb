# Add to a model that can be geolocated, using AddressRecord-style attributes
# (postal_code, region_record_id, region_string instead of zipcode, state_id)
# Expects `latitude` and `longitude` columns to be defined.
module GeocodeableAddressRecord
  extend ActiveSupport::Concern

  included do
    belongs_to :region_record, class_name: "State"
    belongs_to :country

    geocoded_by :address
    before_validation :clean_region_and_street_data
    after_validation :bike_index_geocode, if: :should_be_geocoded? # Geocode using our own geocode process

    scope :with_location, -> { where.not(latitude: nil) }
    scope :with_street, -> { with_location.where.not(street: nil) }
    scope :without_street, -> { where(street: ["", nil]) }

    # Skip geocoding if this flag is truthy
    attr_accessor :skip_geocoding

    def skip_geocoding?
      skip_geocoding.present?
    end
  end

  class << self
    def location_attrs
      %w[country_id region_record_id region_string street city postal_code latitude longitude neighborhood].freeze
    end

    # Build an address string from the given object's location data.
    #
    # The following keyword args accept booleans for inclusion / omission in the
    # string: `street` `city` `region` `postal_code`, `country`.
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
    def address(obj, street: true, city: true, region: true, postal_code: true, country: [:iso])
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
          region && obj.region_abbreviation,
          postal_code && obj.postal_code
        ].reject(&:blank?).join(" "),
        country_name
      ].reject(&:blank?).join(", ")
    end

    def format_postal_code(str, country_id = nil)
      Geocodeable.format_postal_code(str, country_id)
    end
  end

  def address(**kwargs)
    GeocodeableAddressRecord.address(self, **kwargs)
  end

  def without_location?
    latitude.blank?
  end

  def with_location?
    !without_location?
  end

  def latitude_public
    return nil if latitude.blank?
    return latitude unless defined?(show_address)

    show_address ? latitude : latitude.round(Bike::PUBLIC_COORD_LENGTH)
  end

  def longitude_public
    return nil if longitude.blank?
    return longitude unless defined?(show_address)

    show_address ? longitude : longitude.round(Bike::PUBLIC_COORD_LENGTH)
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
    %i[street city region_record_id region_string postal_code country_id]
      .any? { |col| public_send(:"#{col}_changed?") }
  end

  def address_present?
    [street, city, postal_code].any?(&:present?)
  end

  def clean_region_and_street_data
    # remove region_record if it's not for the same country
    if country_id.present? && region_record_id.present?
      self.region_record_id = nil unless region_record&.country_id == country_id
    end
    self.street = street.blank? ? nil : street.strip.gsub(/\s*,\z/, "")
    self.city = city.blank? ? nil : clean_city(city)
    self.postal_code = postal_code.blank? ? nil : GeocodeableAddressRecord.format_postal_code(postal_code, country_id)
    assign_region_record
  end

  def bike_index_geocode
    # Only geocode if there is specific location information
    self.attributes = if address_present?
      GeocodeHelper.coordinates_for(address)
    else
      {latitude: nil, longitude: nil}
    end
  end

  def address_hash
    address_attrs = GeocodeableAddressRecord.location_attrs - %w[country_id country region_record_id region_string neighborhood]
    attributes.slice(*address_attrs)
      .merge(region: region_abbreviation, country: country_abbr)
      .to_a.map { |k, v| [k, v.blank? ? nil : v] }.to_h # Return blank attrs as nil
      .with_indifferent_access
  end

  def region_abbreviation
    region_record&.abbreviation || region_string
  end

  def region_name
    region_record&.name || region_string
  end

  # Override assignment to enable friendly finding region_record and country
  def region_record=(val)
    if val.is_a?(String)
      self.region_record = State.friendly_find(val)
    else
      super
    end
  end

  def country=(val)
    if val.is_a?(String)
      self.country = Country.friendly_find(val)
    else
      super
    end
  end

  def country_abbr
    country&.iso
  end

  def metric_units?
    country.blank? || !country.united_states?
  end

  private

  def assign_region_record
    self.region_string = nil if region_string.blank? || region_record.present?
    if region_string.present?
      self.region_record_id = State.friendly_find(region_string, country_id:)&.id
      self.region_string = nil if region_record_id.present?
    end
  end

  # remove ", CA" for things like "Sacramento, CA"
  # Assign region_record if not assigned.
  # Only works for USA because states only work in US :(
  def clean_city(str)
    if str.match?(/(,|\.)\s*\w\w\s*\z/) && country_id == Country.united_states_id
      str_region_abbr = str[/(,|\.)\s*\w\w\s*\z/].gsub(/,|\./, "").strip.downcase
      str_no_region = str.gsub(/(,|\.)\s*\w\w\s*\z/, "")
      if region_record_id.present?
        if region_record.abbreviation.downcase == str_region_abbr
          str = str_no_region
        end
      else
        citys_region = State.fuzzy_abbr_find(str_region_abbr)
        if citys_region.present?
          self.region_record_id = citys_region.id
          str = str_no_region
        end
      end
    end
    str.strip.gsub(/\s*,\z/, "")
  end
end
