# frozen_string_literal: true

module Geocodeable
  extend ActiveSupport::Concern

  RENDER_COUNTRY_OPTIONS = [:if_different, true, false].freeze
  ADDRESS_ATTRS = %i[city country_id postal_code region_record_id region_string street street_2].freeze
  GEO_ATTRS = (ADDRESS_ATTRS + %i[latitude longitude]).freeze

  class << self
    def attrs_to_duplicate(obj)
      if obj.is_a?(AddressRecord)
        obj.internal_address_attrs.merge(skip_geocoding: obj.latitude.present?, skip_callback_job: true)
      elsif defined?(obj.address_record) && obj.address_record.present?
        attrs_to_duplicate(obj.address_record)
      elsif defined?(obj.street)
        attrs_from_legacy(obj)
      else
        {}
      end
    end

    private

    def attrs_from_legacy(obj)
      {
        skip_geocoding: obj.latitude.present?, # Skip geocoding if already geocoded
        skip_callback_job: true, # they're already in sync
        street: obj.street,
        city: obj.city,
        region_record_id: obj.state_id,
        postal_code: obj.zipcode,
        country_id: obj.country_id,
        latitude: obj.latitude,
        longitude: obj.longitude
      }
    end
  end

  included do
    before_validation :clean_location_attributes

    belongs_to :country
    belongs_to :region_record, class_name: "State"
  end

  def metric_units?
    Country.metric_units?(country_id)
  end

  def to_coordinates
    [latitude, longitude]
  end

  def with_location?
    latitude.present?
  end

  def without_location?
    latitude.blank?
  end

  def address_present?
    [street, postal_code, city].any?(&:present?)
  end

  def country_iso
    country&.iso
  end

  def country_name
    country&.name
  end

  # Enable assigning string countries
  def country=(val)
    self.country_id = if val.is_a?(String) || val.is_a?(Numeric)
      Country.friendly_find_id(val)
    elsif val.respond_to?(:id)
      val.id
    end
  end

  def region(full_region: false)
    return region_string unless region_record.present?

    full_region ? region_record.name : region_record.abbreviation
  end

  def address_hash(visible_attribute: nil, render_country: nil, current_country_id: nil, current_country_iso: nil)
    include_country = include_country?(render_country:, current_country_id:, current_country_iso:)
    country_hash = (include_country && country&.name.present?) ? {country: country.name} : {}
    visible_attr = self.class.permitted_visible_attribute(visible_attribute, default: publicly_visible_attribute)
    {
      street: %i[street].include?(visible_attr) ? street : nil,
      street_2: %i[street].include?(visible_attr) ? street_2 : nil,
      city:,
      region:,
      postal_code: %i[street postal_code].include?(visible_attr) ? postal_code : nil,
      latitude:, longitude:
    }.merge(country_hash)
  end

  def address_hash_legacy(address_record_id: false)
    l_hash = address_hash(visible_attribute: :street, render_country: true).dup
    l_hash[:zipcode] = l_hash.delete(:postal_code)
    l_hash[:state] = l_hash.delete(:region)
    l_hash[:address_record_id] = id if address_record_id
    l_hash.with_indifferent_access
  end

  def formatted_address_string(visible_attribute: nil, render_country: nil, current_country_id: nil, current_country_iso: nil)
    f_hash = address_hash(visible_attribute:, render_country:, current_country_id:, current_country_iso:)
    arr = f_hash.values_at(:street, :street_2, :city)
    arr << f_hash.values_at(:region, :postal_code).reject(&:blank?).join(" ") # region and postal code don't have a comma
    (arr << f_hash[:country]).reject(&:blank?).join(", ")
  end

  def internal_address_attrs
    slice(*GEO_ATTRS)
  end

  private

  def clean_location_attributes
    self.street = Binxtils::InputNormalizer.string(street)
    self.street_2 = Binxtils::InputNormalizer.string(street_2)
    self.postal_code = Binxtils::InputNormalizer.string(postal_code)
    self.city = Binxtils::InputNormalizer.string(city)
    self.neighborhood = Binxtils::InputNormalizer.string(neighborhood)
    self.postal_code = GeocodeHelper.format_postal_code(postal_code, country_id) if postal_code.present?

    assign_region_record
  end

  def include_country?(render_country: nil, current_country_id: nil, current_country_iso: nil)
    render_country = render_country&.to_s
    return render_country == "true" if %w[true false].include?(render_country)

    render_sym = render_country&.to_sym
    RENDER_COUNTRY_OPTIONS.first unless RENDER_COUNTRY_OPTIONS.include?(render_sym)

    if current_country_iso.present?
      country_iso != current_country_iso&.strip&.upcase
    else
      # default to US if no current country is passed
      country_id != (current_country_id || Country.united_states_id)
    end
  end

  def assign_region_record
    self.region_string = nil if region_string.blank?

    # Only remove region_string if region_record.present
    self.region_string = nil if region_record.present?

    if region_string.present?
      self.region_record_id = State.friendly_find(region_string, country_id:)&.id
      self.region_string = nil if region_record_id.present?
    end
  end

  def address_changed?
    (ADDRESS_ATTRS - %i[street_2]).any? { |col| public_send(:"#{col}_changed?") }
  end

  def address_record_geocode
    # Only geocode if there is specific location information
    unless address_present?
      self.attributes = {latitude: nil, longitude: nil}
      return
    end

    GeocodeHelper.assignable_address_hash_for(
      formatted_address_string(render_country: :always), new_attrs: true
    ).each do |key, value|
      # Don't overwrite any values except latitude and longitude
      if self[key].blank? || %i[latitude longitude].include?(key)
        self[key] = value
      end
    end

    assign_region_record if region_string_changed?
  end
end
