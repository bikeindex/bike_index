class Ticket < ApplicationRecord
  STATUS_ENUM = { unused: 0, in_line: 1, resolved: 2 }.freeze
  CLAIMED_TICKET_LIMIT = 2

  belongs_to :organization
  belongs_to :location
  belongs_to :appointment

  validates_presence_of :location_id, :organization_id
  validates_uniqueness_of :number, scope: [:location_id]

  before_validation :set_calculated_attributes

  enum status: STATUS_ENUM

  scope :number_ordered, -> { reorder(:number) }
  scope :unclaimed, -> { where(claimed_at: nil) }
  scope :claimed, -> { where.not(claimed_at: nil) }
  scope :unresolved, -> { where(status: unresolved_statuses) }

  def self.statuses; STATUS_ENUM.keys.map(&:to_s) end

  def self.unresolved_statuses; statuses - ["resolved"] end

  # For now, it's simple, but could become more complicated
  def self.friendly_find(str)
    where(number: str.to_s.strip).first
  end

  def self.create_tickets(number_to_create, initial_number: nil, organization: nil, location: nil)
    location ||= organization.locations.first
    initial_number ||= location.tickets.max_number
    initial_number += 1 if location.tickets.where(number: initial_number).present? || initial_number == 0

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

  # Specifically block a customer from claiming a bunch of tickets and marking them abandoned
  def self.recent_customer_appointment_statuses; Appointment.in_line_statuses + ["abandoned"] end

  def self.too_many_recent_claimed_tickets?(user: nil, user_id: nil, email: nil, creation_ip: nil)
    recent_appointments = Appointment.for_user_attrs(user: user, user_id: user_id, email: email, creation_ip: creation_ip)
                                     .where(status: recent_customer_appointment_statuses)
                                     .where(appointment_at: (Time.current - 1.hour)..(Time.current + 30.minutes))
    recent_appointments.count >= CLAIMED_TICKET_LIMIT
  end

  def claimed?; claimed_at.present? end

  def unresolved?; self.class.unresolved_statuses.include?(status) end

  # Might be more complicated in the future
  def display_number; number end

  def claim(user: nil, user_id: nil, email: nil, creation_ip: nil) # Can just add a phone number here
    return true if appointment&.matches_user_attrs?(user: user, user_id: user_id, email: email)
    errors.add(:base, "appointment already claimed") if appointment_id.present?
    if self.class.too_many_recent_claimed_tickets?(user: user, user_id: user_id, email: email)
      errors.add(:base, "you have already claimed as many tickets as you're allowed!")
    end
    errors.add(:base, "We need your email to contact you about your place in line!") unless [user, user_id, email].reject(&:blank?).any?
    return false if errors.any?
    new_appt = create_new_appointment(user: user, user_id: user_id, email: email, creation_ip: creation_ip)
    self.update(appointment_id: new_appt.id)
    true
  end

  def set_calculated_attributes
    self.organization_id ||= location&.organization_id
    self.link_token ||= SecurityTokenizer.new_token # We always need a link_token
    self.claimed_at ||= Time.current if appointment_id.present?
  end

  def create_new_appointment(email: nil, user_id: nil, user: nil, creation_ip: nil)
    Appointment.create(location_id: location_id,
                       organization_id: organization_id,
                       creator_kind: "ticket_claim",
                       status: "waiting",
                       email: email,
                       user_id: user_id || user&.id,
                       creation_ip: creation_ip,
                       ticket_number: number)
  end
end
