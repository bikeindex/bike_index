class AppointmentConfiguration < ApplicationRecord
  belongs_to :organization
  belongs_to :location

  validates_presence_of :organization_id, :location_id

  before_validation :set_calculated_attributes
  after_commit :update_appointment_queue

  def self.default_reasons
    ["Bike purchase", "Other purchase", "Service"]
  end

  def virtual_line_on?; virtual_line_on end

  # Maybe this will be configurable at some point
  def after_failed_to_find_removal_count; 3 end

  def reasons_text; reasons.join(", ") end

  def reasons_text=(val)
    self.reasons = val.to_s.split(/,|\n/).map(&:strip).reject(&:blank?)
  end

  def set_calculated_attributes
    if customers_on_deck_count.blank? || customers_on_deck_count < 0
      self.customers_on_deck_count = 0
    end
  end

  def update_appointment_queue
    TicketQueueWorker.perform_async(location_id)
  end
end
