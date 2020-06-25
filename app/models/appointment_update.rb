class AppointmentUpdate < ApplicationRecord
  STATUS_ENUM = {
    waiting: 0,
    on_deck: 1,
    being_helped: 2,
    finished: 3,
    failed_to_find: 4,
    removed: 5,
    abandoned: 6,
    organization_reordered: 7,
  }.freeze

  belongs_to :appointment
  belongs_to :user

  validates_presence_of :appointment_id

  enum status: STATUS_ENUM
  enum creator_kind: Appointment::CREATOR_KIND_ENUM

  def self.statuses; STATUS_ENUM.keys.map(&:to_s) end

  def self.update_only_statuses; %w[failed_to_find organization_reordered] end

  def update_only_status?; self.class.update_only_statuses.include?(status) end
end
