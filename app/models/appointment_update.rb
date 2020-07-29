class AppointmentUpdate < ApplicationRecord
  # NOTE: status enum values are in order based on where in the flow the appointment is
  # it's important for ordering that they keep to this order
  STATUS_ENUM = {
    pending: 0,
    waiting: 1,
    organization_reordered: 2,
    on_deck: 3,
    paging: 4,
    # Below are resolved statuses - blank include for potential assignment later
    failed_to_find: 6,
    removed: 7,
    abandoned: 8,
    being_helped: 10, # Another blank before, for potential later assignment
    finished: 11,
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

  def self.customer_update_statuses
    %w[waiting being_helped abandoned].freeze
  end

  def self.update_only_statuses
    %w[failed_to_find organization_reordered].freeze
  end

  def self.in_line_statuses
    %w[waiting on_deck paging].freeze
  end

  def self.paging_or_on_deck_statuses
    %w[on_deck paging].freeze
  end

  def self.resolved_statuses
    %(finished removed being_helped abandoned).freeze
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
