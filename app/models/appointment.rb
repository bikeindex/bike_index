class Appointment < ApplicationRecord
  KIND_ENUM = { virtual_line: 0 }.freeze # Because that's all there is for now
  STATUS_ENUM = { waiting: 0, on_deck: 1, being_helped: 2, finished: 3, failed_to_find: 4, removed: 5 }.freeze

  belongs_to :organization
  belongs_to :location
  belongs_to :user
  belongs_to :bike

  has_many :appointment_updates, dependent: :destroy

  validates_presence_of :organization_id, :location_id, :email, :name

  before_validation :set_calculated_attributes
  after_commit :update_appointment_queue

  enum status: STATUS_ENUM
  enum kind: KIND_ENUM

  scope :in_line, -> { where(status: in_line_statuses) }

  def self.kinds; KIND_ENUM.keys.map(&:to_s) end

  def self.statuses; STATUS_ENUM.keys.map(&:to_s) end

  def self.in_line_statuses; %w[waiting on_deck] end

  def self.resolved_statuses; %[finished removed] end

  def permitted_reasons; location.appointment_configuration.reasons end

  # Deal with deleted locations, etc
  def location; Location.unscoped.find_by_id(location_id) end

  def signed_in_user?; user_id.present? end

  def in_line?; self.class.in_line_statuses.include?(status) end

  def failed_to_find_attempts; appointment_updates.failed_to_find end

  def set_calculated_attributes
    self.link_token ||= SecurityTokenizer.new_token # We always need a link_token
    self.kind = self.class.kinds.first # Because we're only doing virtual_line for now
    self.appointment_time ||= Time.current # Because it's virtual_line
    self.email = EmailNormalizer.normalize(email)
    # TODO: ensure location matches organization
    # errors.add(:base, "bad location!") unless location&.organization_id == organization_id
  end

  def update_appointment_queue
    LocationAppointmentsQueueWorker.perform_async(location_id)
  end
end
