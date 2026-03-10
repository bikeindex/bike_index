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

  def address_hash
    %w[street city postal_code latitude longitude]
      .index_with { |attr| attributes[attr].presence }
      .merge("region" => region_abbreviation, "country" => country_iso)
      .with_indifferent_access
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

  # TODO: Make this work
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
