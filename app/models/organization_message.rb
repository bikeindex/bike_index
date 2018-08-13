# frozen_string_literal: true

class OrganizationMessage < ActiveRecord::Base
  KIND_ENUM = { geolocated: 0, abandoned_bike: 1 }.freeze

  belongs_to :organization
  belongs_to :sender, class_name: "User"
  belongs_to :bike

  validates_presence_of :organization_id, :sender_id, :email

  enum kind: KIND_ENUM

  before_validation :set_calculated_attributes
  before_validation :validate_requirements_for_kind
  after_create :send_email_message

  def set_calculated_attributes
    self.email ||= bike.owner_email
    if latitude.present? && longitude.present?
      self.address ||= Geohelper.reverse_geocode(latitude, longitude)
    elsif address.present?
      coordinates = Geohelper.coordinates_for(address)
      self.attributes = coordinates if coordinates.present?
    end
  end

  def validate_requirements_for_kind # currently all require geolocation and bike, but eventually some won't, e.g. partial registrations
    self.errors.add(:bike, "Required") unless bike.present?
    self.errors.add(:location, "(latitude and longitude) required") unless latitude.present? && longitude.present?
    true # Legacy concerns, so excited for TODO: Rails 5 update
  end

  def send_email_message
    EmailOrganizationMessageWorker.perform_async(id)
  end

  def subject
    "#{organization.short_name} - the location of your #{bike.mnfg_name}"
  end
end
