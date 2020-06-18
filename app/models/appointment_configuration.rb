class AppointmentConfiguration < ApplicationRecord
  belongs_to :organization
  belongs_to :location

  validates_presence_of :organization_id, :location_id

  def self.default_reasons
    ["Bike purchase", "Other purchase", "Service"]
  end

  def virtual_line_enabled?; virtual_line_enabled end
end
