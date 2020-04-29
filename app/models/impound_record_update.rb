class ImpoundRecordUpdate < ApplicationRecord
  # These statuses overlap with impound_records! The resolved statuses need to match up
  KIND_ENUM = { note: 0, move_location: 1, retrieved_by_owner: 2, removed_from_bike_index: 3, transferred_to_new_owner: 4 }.freeze

  belongs_to :impound_record
  belongs_to :user
  belongs_to :location

  validates_presence_of :impound_record_id, :user_id
  validates_presence_of :transfer_email, if: :transferred_to_new_owner?
  validates_presence_of :location_id, if: :move_location?

  after_commit :update_associations

  enum kind: KIND_ENUM

  scope :active, -> { where(kind: active_kinds) }
  scope :resolved, -> { where(kind: resolved_kinds) }
  scope :with_location, -> { where.not(location_id: nil) }
  scope :unresolved, -> { where(resolved: false) } # Means the update worker hasn't taken care of them

  def self.kinds; KIND_ENUM.keys.map(&:to_s) end

  def self.active_kinds; %w[note move_location] end

  def self.resolved_kinds; kinds - active_kinds end

  def self.kinds_without_location; kinds - ["move_location"] end

  def self.kinds_humanized
    {
      note: "Add internal note",
      move_location: "Update location",
      retrieved_by_owner: "Owner retrieved bike",
      removed_from_bike_index: "Removed from Bike Index",
      transferred_to_new_owner: "Transferred to new owner",
      current: "Current",
    }
  end

  def self.kinds_humanized_short
    {
      current: "Current",
      note: "Note",
      move_location: "Moved",
      retrieved_by_owner: "Retrieved",
      removed_from_bike_index: "Trashed",
      transferred_to_new_owner: "Transferred",
    }
  end

  def active?; self.class.active_kinds.include?(kind) end

  def resolved?; !active? end

  def kind_humanized; self.class.kinds_humanized[kind.to_sym] end

  def update_associations
    impound_record&.update(updated_at: Time.current)
  end
end
