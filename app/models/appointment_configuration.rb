class AppointmentConfiguration < ApplicationRecord
  belongs_to :organization
  belongs_to :location

  validates_presence_of :organization_id, :location_id

  def self.default_reasons
    ["Bike purchase", "Other purchase", "Service"]
  end

  def virtual_line_on?; virtual_line_on end

  def reasons_text; reasons.join(", ") end

  def reasons_text=(val)
    self.reasons = val.to_s.split(/,|\n/).map(&:strip).reject(&:blank?)
  end
end
