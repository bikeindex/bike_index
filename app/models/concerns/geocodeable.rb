# Add to a model that can be geolocated
# Expects `latitude` and `longitude` columns to be defined.
module Geocodeable
  extend ActiveSupport::Concern

  included do
    belongs_to :state
    belongs_to :country

    geocoded_by :address
    before_validation :clean_state_and_street_data
    after_validation :bike_index_geocode, if: :should_be_geocoded? # Geocode using our own geocode process

    # TODO: Make without_location be without_street everywhere (removing with_location, etc)
    scope :with_location, -> { where.not(latitude: nil) }
    scope :with_street, -> { with_location.where.not(street: nil) }
    scope :without_street, -> { where(street: ["", nil]) }
    # NOTE: without_location not included because it's overridden in stolen_record, which warns everytime it's loaded
    # ... this is part of the without_location reconcilliation above

    # Skip geocoding if this flag is truthy
    attr_accessor :skip_geocoding

    def skip_geocoding?
      skip_geocoding.present?
    end
  end

  class << self
    def location_attrs
      %w[country_id state_id street city zipcode latitude longitude neighborhood].freeze
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
    def address(obj, street: true, city: true, state: true, zipcode: true, country: [:iso])
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

    def format_postal_code(str, country_id = nil)
      str = str.strip.upcase.gsub(/\s*,\z/, "")
      return str unless country_id == Country.canada_id && str.gsub(/\s+/, "").length == 6

      str.gsub(/\s+/, "").scan(/.{1,3}/).join(" ")
    end

    def new_address_hash(address_hash)
      new_hash = address_hash.dup.symbolize_keys
      new_hash[:postal_code] = new_hash.delete(:zipcode)
      new_hash[:region] = new_hash.delete(:state)
      new_hash[:country] = Country.friendly_find(new_hash.delete(:country))&.name
      new_hash
    end
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

  # stolen_record and impound_record
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
    %i[street city state_id zipcode country_id]
      .any? { |col| public_send(:"#{col}_changed?") }
  end

  def address_present?
    [street, city, zipcode].any?(&:present?)
  end

  # Separate from bike_index_geocode because some models handle geocoding independently
  def clean_state_and_street_data
    # remove state if it's not for the same country - we currently only handle us states
    if country_id.present? && state_id.present?
      self.state_id = nil unless state&.country_id == country_id
    end
    self.street = street.blank? ? nil : street.strip.gsub(/\s*,\z/, "")
    self.city = city.blank? ? nil : clean_city(city)
    self.zipcode = zipcode.blank? ? nil : Geocodeable.format_postal_code(zipcode, country_id)
  end

  def bike_index_geocode
    # Only geocode if there is specific location information
    self.attributes = if address_present?
      GeocodeHelper.coordinates_for(address)
    else
      {latitude: nil, longitude: nil}
    end
  end

  # default address hash. Probably could be used more often/better
  def address_hash
    address_attrs = Geocodeable.location_attrs - %w[country_id country state_id state neighborhood]
    attributes.slice(*address_attrs)
      .merge(state: state_abbr, country: country_abbr)
      .to_a.map { |k, v| [k, v.blank? ? nil : v] }.to_h # Return blank attrs as nil
      .with_indifferent_access
  end

  def address_hash_new_attrs
    Geocodeable.new_address_hash(address_hash)
  end

  # Override assignment to enable friendly finding state and country
  def state=(val)
    if val.is_a?(String)
      self.state = State.friendly_find(val)
    else
      super
    end
  end

  def state_abbr
    state&.abbreviation
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

  # remove ", CA" for things like "Sacramento, CA"
  # Assign state if not assigned.
  # Only works for USA because states only work in US :(
  def clean_city(str)
    if str.match?(/(,|\.)\s*\w\w\s*\z/) && country_id == Country.united_states_id
      str_state_abbr = str[/(,|\.)\s*\w\w\s*\z/].gsub(/,|\./, "").strip.downcase
      str_no_state = str.gsub(/(,|\.)\s*\w\w\s*\z/, "")
      if state_id.present?
        if state.abbreviation.downcase == str_state_abbr
          str = str_no_state
        end
      else
        citys_state = State.fuzzy_abbr_find(str_state_abbr)
        if citys_state.present?
          self.state_id = citys_state.id
          str = str_no_state
        end
      end
    end
    str.strip.gsub(/\s*,\z/, "")
  end
end
