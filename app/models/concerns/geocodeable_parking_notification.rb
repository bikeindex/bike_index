# Geocoding and address handling for ParkingNotification.
# Includes Geocodeable and adds ParkingNotification-specific address behavior:
# - geocoded_by :address (for bounding box search)
# - skip_geocoding support
# - latitude_public/longitude_public (respects hide_address)
# - simplified address/address_hash (no visibility levels or street_2)
module GeocodeableParkingNotification
  extend ActiveSupport::Concern
  include Geocodeable

  included do
    geocoded_by :address

    attr_accessor :skip_geocoding

    scope :with_location, -> { where.not(latitude: nil) }
    scope :with_street, -> { with_location.where.not(street: nil) }
    scope :without_street, -> { where(street: ["", nil]) }
  end

  def skip_geocoding?
    skip_geocoding.present?
  end

  def latitude_public
    return nil if latitude.blank?

    show_address ? latitude : latitude.round(Bike::PUBLIC_COORD_LENGTH)
  end

  def longitude_public
    return nil if longitude.blank?

    show_address ? longitude : longitude.round(Bike::PUBLIC_COORD_LENGTH)
  end

  def region_abbreviation
    region_record&.abbreviation || region_string
  end

  def region_name
    region_record&.name || region_string
  end

  def address_hash
    %w[street city postal_code latitude longitude]
      .index_with { |attr| attributes[attr].presence }
      .merge("region" => region_abbreviation, "country" => country_iso)
      .with_indifferent_access
  end

  # Override assignment to enable friendly finding region_record
  def region_record=(val)
    if val.is_a?(String)
      self.region_record = State.friendly_find(val)
    else
      super
    end
  end

  # ParkingNotification doesn't have street_2; exclude from GEO_ATTRS
  def internal_address_attrs
    slice(*(Geocodeable::GEO_ATTRS - %i[street_2]))
  end

  def address(force_show_address: false, country: [:iso, :optional, :skip_default])
    self.class.format_address(
      self,
      street: force_show_address || show_address,
      country: country
    ).presence
  end

  module ClassMethods
    def format_address(obj, street: true, city: true, region: true, postal_code: true, country: [:iso])
      return "" if obj.blank?

      include_country = country && !(obj.country&.default? && country.include?(:skip_default))

      country_name =
        if include_country
          country_format = country.find { |e| e.in? %i[iso name] } || :iso
          country_name = obj.country&.public_send(country_format)
          return "" if !country.include?(:optional) && country_name.blank?

          country_name
        end

      [
        street && obj.street,
        city && obj.city,
        [region && obj.region_abbreviation, postal_code && obj.postal_code].reject(&:blank?).join(" "),
        country_name
      ].reject(&:blank?).join(", ")
    end
  end

  private

  # Override Geocodeable's clean_location_attributes
  # ParkingNotification doesn't have street_2; uses clean_city for region extraction
  def clean_location_attributes
    if country_id.present? && region_record_id.present?
      self.region_record_id = nil unless region_record&.country_id == country_id
    end
    self.street = street.blank? ? nil : street.strip.gsub(/\s*,\z/, "")
    self.city = city.blank? ? nil : clean_city(city)
    self.postal_code = postal_code.blank? ? nil : Geocodeable.format_postal_code(postal_code, country_id)
    assign_region_record
  end

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
