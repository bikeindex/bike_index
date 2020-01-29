# frozen_string_literal: true

class AbandonedRecord < ActiveRecord::Base
  KIND_ENUM = { appears_forgotten: 0, parked_incorrectly: 1 }.freeze
  belongs_to :bike
  belongs_to :user
  belongs_to :organization
  belongs_to :impound_record
  belongs_to :initial_abandoned_record
  # has_many :repeat_abandoned_records

  validates_presence_of :bike_id, :user_id
  validate :location_present, on: :create

  before_validation :set_calculated_attributes
  after_commit :update_associations

  enum kind: KIND_ENUM

  scope :current, -> { where(retrieved_at: nil, impound_record_id: nil) }
  scope :initial_record, -> { where(initial_abandoned_record: nil) }
  scope :repeat_record, -> { where.not(initial_abandoned_record: nil) }
  scope :impounded, -> { where.not(impound_record_id: nil) }
  scope :retrieved, -> { where.not(retrieved_at: nil) }

  def self.kinds; KIND_ENUM.keys.map(&:to_s) end

  def current?; !retrieved? && !impounded? end

  def retrieved?; retrieved_at.present? end

  def impounded?; impound_record_id.present? end

  def initial_record?; initial_abandoned_record_id.blank? end

  def repeat_record?; initial_abandoned_record_id.present? end

  def owner_known?; bike.present? && bike.created_at < (Time.current - 1.day) end

  def send_message?; owner_known? end

  def set_calculated_attributes
    if latitude.present? && longitude.present?
      self.address ||= Geohelper.reverse_geocode(latitude, longitude)
    elsif address.present?
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
    # repeat_abandoned_records.map(&:update)
    bike&.update_attributes(updated_at: Time.current)
  end
end
