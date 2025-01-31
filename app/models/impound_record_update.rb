# == Schema Information
#
# Table name: impound_record_updates
#
#  id                :bigint           not null, primary key
#  kind              :integer
#  notes             :text
#  processed         :boolean          default(FALSE)
#  transfer_email    :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  impound_claim_id  :bigint
#  impound_record_id :bigint
#  location_id       :bigint
#  user_id           :bigint
#
class ImpoundRecordUpdate < ApplicationRecord
  # These statuses are used by impound_records!
  KIND_ENUM = {
    current: 0,
    move_location: 1,
    retrieved_by_owner: 2,
    removed_from_bike_index: 3,
    transferred_to_new_owner: 4,
    note: 5,
    claim_approved: 6,
    claim_denied: 7,
    expired: 8
  }.freeze

  belongs_to :impound_record
  belongs_to :impound_claim
  belongs_to :user
  belongs_to :location

  validates_presence_of :impound_record_id
  validates_presence_of :user_id, if: :user_required?
  validates_presence_of :transfer_email, if: :transferred_to_new_owner?
  validates_presence_of :location_id, if: :move_location?

  after_commit :update_associations

  enum :kind, KIND_ENUM

  scope :active, -> { where(kind: active_kinds) }
  scope :resolved, -> { where(kind: resolved_kinds) }
  scope :with_location, -> { where.not(location_id: nil) }
  scope :unprocessed, -> { where(processed: false) } # Means the update worker hasn't taken care of them

  attr_accessor :skip_update

  def self.kinds
    KIND_ENUM.keys.map(&:to_s)
  end

  def self.active_kinds
    %w[current note move_location claim_approved claim_denied]
  end

  def self.resolved_kinds
    kinds - active_kinds
  end

  def self.no_user_required_kinds
    %w[expired]
  end

  def self.update_only_kinds
    %w[move_location note claim_approved claim_denied]
  end

  def self.kinds_humanized
    {
      current: "Current",
      note: "Add internal note",
      move_location: "Update location",
      retrieved_by_owner: "Owner retrieved bike",
      removed_from_bike_index: "Removed from Bike Index",
      transferred_to_new_owner: "Transferred to new owner",
      claim_approved: "Claim approved",
      claim_denied: "Claim denied",
      expired: "Removed after expiration period"
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
      claim_approved: "Claim approved",
      claim_denied: "Claim denied",
      expired: "Expired"
    }
  end

  def active?
    self.class.active_kinds.include?(kind)
  end

  def resolved?
    !active?
  end

  def unprocessed?
    !processed
  end

  def user_required?
    !self.class.no_user_required_kinds.include?(kind)
  end

  def kind_humanized
    self.class.kinds_humanized[kind&.to_sym]
  end

  def update_associations
    return true if skip_update
    impound_record&.update(updated_at: Time.current)
    impound_claim&.update(updated_at: Time.current)
  end
end
