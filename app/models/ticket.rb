class Ticket < ApplicationRecord
  STATUS_ENUM = { unused: 0, in_line: 1, resolved: 2 }.freeze

  belongs_to :organization
  belongs_to :location
  belongs_to :appointment

  validates_presence_of :location_id, :organization_id
  validates_uniqueness_of :number, scope: [:location_id]

  before_validation :set_calculated_attributes

  enum status: STATUS_ENUM

  scope :number_ordered, -> { reorder(:number) }
  scope :unresolved, -> { where(status: unresolved_statuses) }

  def self.statuses; STATUS_ENUM.keys.map(&:to_s) end

  def self.unresolved_statuses; statuses - ["resolved"] end

  def self.create_tickets(number_to_create, initial_number: nil, organization: nil, location:)
    initial_number ||= location.tickets.max_number
    initial_number += 1 if location.tickets.where(number: initial_number).present?

    number_to_create.times.map do |i|
      create!(
        organization: organization,
        location: location,
        number: initial_number + i,
      )
    end
  end

  def self.min_number; minimum(:number) || 0 end

  def self.max_number; maximum(:number) || 0 end

  def unresolved?; self.class.unresolved_statuses.include?(status) end

  def display_number; number end

  def existing_or_new_appointment
    return appointment if appointment.present?
    new_appt = Appointment.create!(location_id: location_id,
                                   organization_id: organization_id,
                                   creator_kind: "ticket_scan",
                                   status: "waiting")
    self.update(appointment_id: new_appt.id, status: "in_line")
    new_appt
  end

  def set_calculated_attributes
    self.organization_id ||= location&.organization_id
    self.link_token ||= SecurityTokenizer.new_token # We always need a link_token
  end
end
