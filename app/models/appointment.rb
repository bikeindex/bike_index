# t.references :location
# t.references :organization
# t.references :user
# t.references :bike

# t.string :email
# t.text :link_token

# t.integer :status
# t.integer :kind

# t.string :reason
# t.text :description

# t.datetime :appointment_time

class Appointment < ApplicationRecord
  KIND_ENUM = { virtual_line: 0 }.freeze # Because that's all there is for now
  STATUS_ENUM = { in_line: 0, on_deck: 1, being_helped: 2, finished: 3, failed_to_find: 4, removed: 5 }.freeze

  belongs_to :organization
  belongs_to :location
  belongs_to :user
  belongs_to :bike

  has_many :appointment_updates, dependent: :destroy

  validates_presence_of :organization_id, :location_id

  before_validation :set_calculated_attributes

  enum status: STATUS_ENUM
  enum kind: KIND_ENUM

  def self.kinds; KIND_ENUM.keys.map(&:to_s) end

  def self.statuses; STATUS_ENUM.keys.map(&:to_s) end

  def self.waiting_statuses; %w[in_line on_deck] end

  def self.resolved_statuses; %[finished removed] end

  def signed_in_user?; user_id.present? end

  def waiting?; self.class.waiting_statuses.include?(status) end

  def failed_to_find_attempts; appointment_updates.failed_to_find end

  def set_calculated_attributes
    self.link_token ||= SecurityTokenizer.new_token # We always need a link_token
    self.kind = self.class.kinds.first # Because we're only doing virtual_line for now
    self.appointment_time ||= Time.current # Because it's virtual_line
  end
end
