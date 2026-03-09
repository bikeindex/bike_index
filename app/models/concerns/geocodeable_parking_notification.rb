# Geocoding and address handling for ParkingNotification.
# Uses address_record-style columns: postal_code, region_record_id, region_string.
module GeocodeableParkingNotification
  extend ActiveSupport::Concern

  included do
    belongs_to :region_record, class_name: "State"
    belongs_to :country

    geocoded_by :address

    attr_accessor :skip_geocoding

    before_validation :clean_region_and_street_data

    scope :with_location, -> { where.not(latitude: nil) }
    scope :with_street, -> { with_location.where.not(street: nil) }
    scope :without_street, -> { where(street: ["", nil]) }
  end

  class << self
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

  def skip_geocoding?
    skip_geocoding.present?
  end

  def without_location?
    latitude.blank?
  end

  def with_location?
    !without_location?
  end

  def latitude_public
    return nil if latitude.blank?

    show_address ? latitude : latitude.round(Bike::PUBLIC_COORD_LENGTH)
  end

  def longitude_public
    return nil if longitude.blank?

    show_address ? longitude : longitude.round(Bike::PUBLIC_COORD_LENGTH)
  end

  def address_changed?
    %i[street city region_record_id region_string postal_code country_id]
      .any? { |col| public_send(:"#{col}_changed?") }
  end

  def address_present?
    [street, city, postal_code].any?(&:present?)
  end

  def region_abbreviation
    region_record&.abbreviation || region_string
  end

  def region_name
    region_record&.name || region_string
  end

  def country_abbr
    country&.iso
  end

  def metric_units?
    country.blank? || !country.united_states?
  end

  def address_hash
    %w[street city postal_code latitude longitude]
      .index_with { |attr| attributes[attr].presence }
      .merge("region" => region_abbreviation, "country" => country_abbr)
      .with_indifferent_access
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

  def address(force_show_address: false, country: [:iso, :optional, :skip_default])
    GeocodeableParkingNotification.format_address(
      self,
      street: force_show_address || show_address,
      country: country
    ).presence
  end

  private

  def clean_region_and_street_data
    if country_id.present? && region_record_id.present?
      self.region_record_id = nil unless region_record&.country_id == country_id
    end
    self.street = street.blank? ? nil : street.strip.gsub(/\s*,\z/, "")
    self.city = city.blank? ? nil : clean_city(city)
    self.postal_code = postal_code.blank? ? nil : GeocodeHelper.format_postal_code(postal_code, country_id)
    assign_region_record
  end

  def assign_region_record
    self.region_string = nil if region_string.blank? || region_record.present?
    if region_string.present?
      self.region_record_id = State.friendly_find(region_string, country_id:)&.id
      self.region_string = nil if region_record_id.present?
    end
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
