# frozen_string_literal: true

class ParkingNotification < ActiveRecord::Base
  KIND_ENUM = { appears_abandoned: 0, parked_incorrectly: 1 }.freeze
  belongs_to :bike
  belongs_to :user
  belongs_to :organization
  belongs_to :impound_record
  belongs_to :initial_record
  # has_many :repeat_parking_notifications
  belongs_to :country
  belongs_to :state

  validates_presence_of :bike_id, :user_id
  validate :location_present, on: :create

  before_validation :set_calculated_attributes
  after_commit :update_associations

  enum kind: KIND_ENUM

  # TODO: location refactor - switch to Geocodeable
  geocoded_by :geocode_data

  scope :current, -> { where(retrieved_at: nil, impound_record_id: nil) }
  scope :initial_records, -> { where(initial_record_id: nil) }
  scope :repeat_record, -> { where.not(initial_record_id: nil) }
  scope :impounded, -> { where.not(impound_record_id: nil) }
  scope :retrieved, -> { where.not(retrieved_at: nil) }

  def self.kinds; KIND_ENUM.keys.map(&:to_s) end

  def current?; !retrieved? && !impounded? end

  def retrieved?; retrieved_at.present? end

  def impounded?; impound_record_id.present? end

  def initial_record?; initial_record_id.blank? end

  def repeat_record?; initial_record_id.present? end

  def owner_known?; bike.present? && bike.created_at < (Time.current - 1.day) end

  def send_message?; owner_known? end

  def show_address; !hide_address end

  def kind_humanized; kind.gsub("_", " ") end # This might become more sophisticated...

  # TODO: location refactor - copied method from stolen
  def address(skip_default_country: false, override_show_address: false)
    return if country&.iso.blank?

    country_string =
      if country&.iso&.in?(%w[US USA])
        skip_default_country ? nil : "USA"
      else
        country&.iso
      end

    [
      (override_show_address || show_address) ? street : nil,
      city,
      [state&.abbreviation, zipcode].reject(&:blank?).join(" "),
      country_string,
    ].reject(&:blank?).join(", ")
  end

  # TODO: location refactor, use the same attributes for all location models
  def set_calculated_attributes
    return true if street.present? && latitude.present? && longitude.present?
    if latitude.present? && longitude.present?
      addy_hash = Geohelper.formatted_address_hash(Geohelper.reverse_geocode(latitude, longitude))
      self.street = addy_hash["address"]
      self.city = addy_hash["city"]
      self.zipcode = addy_hash["zipcode"]
      self.country = Country.fuzzy_find(addy_hash["country"])
      self.state = State.fuzzy_find(addy_hash["state"])
    else
      coordinates = Geohelper.coordinates_for(address)
      self.attributes = coordinates if coordinates.present?
    end
  end

  def location_present
    # in case geocoder is failing (which happens sometimes), permit if either is present
    return true if latitude.present? && longitude.present? || address.present?
    self.errors.add(:address, :address_required)
  end

  def update_associations
    # repeat_parking_notifications.map(&:update)
    bike&.update_attributes(updated_at: Time.current)
  end
end
