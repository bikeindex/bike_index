class AppointmentUpdate < ApplicationRecord
  STATUS_ENUM = {
    pending: 0,
    waiting: 1,
    paging: 2,
    on_deck: 3,
    being_helped: 4,
    finished: 5,
    failed_to_find: 6,
    removed: 7,
    abandoned: 8,
    organization_reordered: 9
  }.freeze

  CREATOR_KIND_ENUM = {
    no_user: 0,
    signed_in_user: 1,
    organization_member: 2,
    queue_worker: 3
  }

  belongs_to :appointment
  belongs_to :user

  validates_presence_of :appointment_id

  enum status: STATUS_ENUM
  enum creator_kind: CREATOR_KIND_ENUM

  def self.statuses
    STATUS_ENUM.keys.map(&:to_s)
  end

  def self.update_only_statuses
    %w[failed_to_find organization_reordered]
  end

  def self.creator_kinds
    CREATOR_KIND_ENUM.keys.map(&:to_s)
  end

  def self.customer_creator_kinds
    %w[no_user signed_in_user]
  end

  def self.customer_creator_kind?(kind)
    customer_creator_kinds.include?(kind)
  end

  def update_only_status?
    self.class.update_only_statuses.include?(status)
  end

  def display_name
    user&.display_name
  end

  def public_display_name
    BadWordCleaner.clean(display_name.to_s.split(" ").first)
  end

  def customer_creator?
    self.class.customer_creator_kind?(creator_kind)
  end
end
