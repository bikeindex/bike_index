# == Schema Information
#
# Table name: address_records
#
#  id                         :bigint           not null, primary key
#  city                       :string
#  kind                       :integer
#  latitude                   :float
#  longitude                  :float
#  neighborhood               :string
#  postal_code                :string
#  publicly_visible_attribute :integer
#  region_string              :string
#  street                     :string
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  country_id                 :bigint
#  region_record_id           :bigint
#  user_id                    :bigint
#
# Indexes
#
#  index_address_records_on_country_id        (country_id)
#  index_address_records_on_region_record_id  (region_record_id)
#  index_address_records_on_user_id           (user_id)
#
class AddressRecord < ApplicationRecord
  KIND_ENUM = {user: 0, stolen_record: 1, marketplace: 2}.freeze
  PUBLICLY_VISIBLE_ATTRITBUTE_ENUM = {postal_code: 1, street: 0, city: 2}.freeze
  RENDER_COUNTRY_OPTIONS = %i[if_different always].freeze

  enum :kind, KIND_ENUM
  enum :publicly_visible_attribute, PUBLICLY_VISIBLE_ATTRITBUTE_ENUM

  belongs_to :user
  belongs_to :country
  belongs_to :region_record, class_name: "State"

  has_many :address_records

  before_validation :set_calculated_attributes
  after_validation :address_record_geocode, if: :should_be_geocoded? # Geocode using our own geocode process
  after_commit :update_associations

  attr_accessor :skip_geocoding, :skip_callback_job

  class << self
    def location_attrs
      permitted_params + %i[latitude longitude]
    end

    def permitted_params
      # user_id and kind should be set manually!
      %i[city postal_code region_string street country_id region_record_id].freeze
    end

    def attrs_from_legacy(obj)
      {
        skip_geocoding: true, # Skip geocoding, this is a direct copy
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

    def default_visibility_for(kind)
      (kind == "organization") ? :street : :postal_code
    end
  end

  def address_hash
    attributes.slice(*self.class.location_attrs).symbolize_keys
  end

  def should_be_geocoded?
    !skip_geocoding && address_changed?
  end

  def address_present?
    [street, city, postal_code].any?(&:present?)
  end

  def include_country?(render_country: nil, current_country_iso: nil)
    render = render_country&.to_sym
    render = RENDER_COUNTRY_OPTIONS.first unless RENDER_COUNTRY_OPTIONS.include?(render)
    return true if render == :always

    current_country_iso ||= Country.united_states.iso # Default to US
    country_iso != current_country_iso
  end

  def country_iso
    country&.iso
  end

  def formatted_address_string(render_country: nil, current_country_iso: nil)
    hash_for_formatted_address(render_country:, current_country_iso:, full_region: false)
      .values.reject(&:blank?).join(", ")
  end

  def region(full_region = false)
    if full_region
      region_record.present? ? region_record.name : region_string
    else
      region_record.present? ? region_record.abbreviation : region_string
    end
  end

  private

  def update_associations
    return if skip_callback_job

    ::Callbacks::AddressRecordUpdateAssociationsJob.perform_async(id)
  end

  def set_calculated_attributes
    self.publicly_visible_attribute ||= self.class.default_visibility_for(kind)

    self.street = street.blank? ? nil : street.strip
    self.postal_code = postal_code.blank? ? nil : postal_code.strip
    self.city = city.blank? ? nil : city.strip
    self.neighborhood = neighborhood.blank? ? nil : neighborhood.strip
    assign_region_record
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
    %i[street city region_string region_record_id postal_code country_id]
      .any? { |col| public_send(:"#{col}_changed?") }
  end

  def hash_for_formatted_address(render_country: nil, current_country_iso: nil, full_region: false)
    include_country = include_country?(render_country:, current_country_iso:)
    {
      street: %w[street].include?(publicly_visible_attribute) ? street : nil,
      city:,
      region: region(full_region),
      postal_code: %w[street postal_code].include?(publicly_visible_attribute) ? postal_code : nil,
      country: include_country ? country&.name : nil
    }
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
