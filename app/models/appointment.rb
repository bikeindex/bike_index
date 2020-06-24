class Appointment < ApplicationRecord
  KIND_ENUM = { virtual_line: 0 }.freeze # Because that's all there is for now
  CREATOR_TYPE_ENUM = { no_user: 0, signed_in_user: 1, organization: 2 }

  belongs_to :organization
  belongs_to :location
  belongs_to :user
  belongs_to :bike

  has_many :appointment_updates, dependent: :destroy

  validates_presence_of :organization_id, :location_id, :name

  before_validation :set_calculated_attributes
  after_commit :update_appointment_queue

  enum status: AppointmentUpdate::STATUS_ENUM
  enum kind: KIND_ENUM
  enum creator_type: CREATOR_TYPE_ENUM

  scope :line_ordered, -> { reorder(line_entry_timestamp: :asc) }
  scope :in_line, -> { line_ordered.where(status: in_line_statuses) }

  def self.kinds; KIND_ENUM.keys.map(&:to_s) end

  def self.statuses; AppointmentUpdate.statuses end

  def self.in_line_statuses; %w[waiting on_deck] end

  def self.resolved_statuses; %[finished removed] end

  def permitted_reasons; location.appointment_configuration.reasons end

  # Deal with deleted locations, etc
  def location; Location.unscoped.find_by_id(location_id) end

  def in_line?; self.class.in_line_statuses.include?(status) end

  def failed_to_find_attempts; appointment_updates.failed_to_find end

  def move_behind!(appt_or_appt_id)
    other_appt = appt_or_appt_id.is_a?(Appointment) ? appt_or_appt_id : Appointment.find(appt_or_appt_id)
    self.update(line_entry_timestamp: other_appt.line_entry_timestamp + 1)
  end

  def set_calculated_attributes
    self.link_token ||= SecurityTokenizer.new_token # We always need a link_token
    self.kind = self.class.kinds.first # Because we're only doing virtual_line for now
    self.email = EmailNormalizer.normalize(email)
    self.line_entry_timestamp ||= (created_at || Time.current).to_i # Because it's virtual_line
    # TODO: ensure location matches organization
    # errors.add(:base, "bad location!") unless location&.organization_id == organization_id
  end

  def update_appointment_queue
    LocationAppointmentsQueueWorker.perform_async(location_id)
  end
end
