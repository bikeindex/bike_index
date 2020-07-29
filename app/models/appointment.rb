class Appointment < ApplicationRecord
  KIND_ENUM = {virtual_line: 0}.freeze # Because that's all there is for now

  belongs_to :organization
  belongs_to :location
  belongs_to :user
  belongs_to :bike

  has_many :appointment_updates, dependent: :destroy
  has_many :notifications

  validates_presence_of :organization_id, :location_id, :name

  before_validation :set_calculated_attributes
  after_commit :update_appointment_queue

  enum kind: KIND_ENUM
  enum status: AppointmentUpdate::STATUS_ENUM
  enum creator_kind: AppointmentUpdate::CREATOR_KIND_ENUM

  attr_accessor :skip_update

  # Line ordering is first by the priority of the status, then by line_number
  scope :line_ordered, -> { reorder(status: :desc, line_number: :asc) }
  scope :appointment_update_ordered, -> { includes(:appointment_updates).reorder("appointment_updates.created_at") }
  scope :in_line, -> { where(status: AppointmentUpdate.in_line_statuses).line_ordered }
  scope :paging_or_on_deck, -> { where(status: AppointmentUpdate.paging_or_on_deck_statuses).line_ordered }
  scope :line_not_paging_or_on_deck, -> { where.not(status: AppointmentUpdate.paging_or_on_deck_statuses).in_line }
  scope :recently_updated, -> { includes(:appointment_updates).where("appointment_updates.created_at > ?", Time.current - 15.minutes) }

  def self.kinds
    KIND_ENUM.keys.map(&:to_s)
  end

  # This will be more sophisticated in the future, when we add phone, etc
  def self.for_user_attrs(user: nil, user_id: nil, email: nil, creation_ip: nil)
    unless [user, user_id, email].count(&:present?) == 1
      fail "pass exactly one of: user, user_id, email"
    end
    if user_id.present? || user.present?
      where(user_id: user_id || user.id)
    else
      normalized_email = EmailNormalizer.normalize(email)
      user = User.fuzzy_email_find(normalized_email)
      user.present? ? where(user_id: user.id) : where(email: normalized_email)
    end
  end

  # in most places we're treating IP addresses like strings. Let's keep doing that, at least for now
  def creation_ip=(val)
    new_ip_addr = val.present? ? IPAddr.new(val) : nil
    self.creation_ip_address = new_ip_addr
  rescue IPAddr::Error # We don't want to shit the bed on invalid IP addresses, for now
    nil
  end

  def creation_ip
    creation_ip_address.to_s
  end

  def appointment_configuration
    location.appointment_configuration
  end

  def permitted_reasons
    appointment_configuration.reasons
  end

  # Deal with deleted locations, etc
  def location
    Location.unscoped.find_by_id(location_id)
  end

  def in_line?
    AppointmentUpdate.in_line_statuses.include?(status)
  end

  def claimed?
    user.present?
  end

  def paging_or_on_deck?
    on_deck? || paging?
  end

  def failed_to_find_attempts
    appointment_updates.failed_to_find
  end

  def other_location_appointments
    location.appointments.where.not(id: id)
  end

  def display_name
    name.presence || user&.display_name
  end

  def public_display_name
    BadWordCleaner.clean(display_name.to_s.split(" ").first)
  end

  # same parameters as for_user_attrs - args are in passed_args so they don't override model attributes
  def matches_user_attrs?(passed_args = {})
    passed_user = passed_args[:user]
    passed_user_id = passed_args[:user_id] || passed_user&.id
    passed_email = passed_args[:email]
    if passed_user_id.present? || passed_user.present?
      return true if passed_user_id.to_i == user_id.to_i
      passed_user ||= User.find_by_id(passed_user_id)
      return true if passed_user.all_emails.include?(email)
    end
    if passed_email.present?
      normalized_passed_email = EmailNormalizer.normalize(passed_email)
      return true if normalized_passed_email == email
      return true if user.present? && user.all_emails.include?(normalized_passed_email)
    end
  end

  def record_status_update(updator_kind: "no_user", updator_id: nil, new_status: nil)
    return nil unless new_status.present? && AppointmentUpdate.statuses.include?(new_status) && new_status != status
    # customers can't update their appointment unless it's in line and they're updating to a valid status
    if AppointmentUpdate.customer_creator_kind?(updator_kind)
      return nil if status == "on_deck" && new_status == "waiting" # Don't permit customer putting themselves back into waiting
      return nil unless in_line? && AppointmentUpdate.customer_update_statuses.include?(new_status)
    end
    new_update = appointment_updates.create(creator_kind: updator_kind, user_id: updator_id, status: new_status)

    # We aren't doing anything for the other update_only_statuses, except failed to find, but seems reasonable to skip
    self.status = new_status unless AppointmentUpdate.update_only_statuses.include?(new_status)
    self.skip_update = false # Ensure we run the queue worker
    # Because things might've changed, and even if they didn't we still want to run the queue updator
    update(updated_at: Time.current)
    new_update # Return the created update
  end

  # This is particularly useful for testing
  def record_status_update!(updator_kind: "no_user", updator_id: nil, new_status: nil)
    appt_update = record_status_update(updator_kind: updator_kind, updator_id: updator_id, new_status: new_status)
    return appt_update if appt_update.present?
    fail "unable to record that appointment update"
  end

  def set_calculated_attributes
    self.organization_id ||= location&.organization_id
    self.link_token ||= SecurityTokenizer.new_token # We always need a link_token
    self.kind = self.class.kinds.first # Because we're only doing virtual_line for now
    self.email ||= user&.email
    self.email = EmailNormalizer.normalize(email)
    self.user_id ||= User.fuzzy_email_find(email)&.id if email.present?
    # for now, appointment_at is just the created at. This is setup for when appointments can be scheduled
    self.appointment_at ||= created_at || Time.current
    self.line_number ||= location&.next_line_number
    # TODO: ensure location matches organization
    # errors.add(:base, "bad location!") unless location&.organization_id == organization_id
  end

  def update_appointment_queue
    return true if skip_update
    LocationAppointmentsQueueWorker.perform_async(location_id)
  end
end
