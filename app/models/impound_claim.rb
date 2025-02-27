# == Schema Information
#
# Table name: impound_claims
#
#  id                 :bigint           not null, primary key
#  message            :text
#  resolved_at        :datetime
#  response_message   :text
#  status             :integer
#  submitted_at       :datetime
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  bike_claimed_id    :bigint
#  bike_submitting_id :bigint
#  impound_record_id  :bigint
#  organization_id    :bigint
#  stolen_record_id   :bigint
#  user_id            :bigint
#
# Indexes
#
#  index_impound_claims_on_bike_claimed_id     (bike_claimed_id)
#  index_impound_claims_on_bike_submitting_id  (bike_submitting_id)
#  index_impound_claims_on_impound_record_id   (impound_record_id)
#  index_impound_claims_on_organization_id     (organization_id)
#  index_impound_claims_on_stolen_record_id    (stolen_record_id)
#  index_impound_claims_on_user_id             (user_id)
#
class ImpoundClaim < ApplicationRecord
  STATUS_ENUM = {
    pending: 0,
    submitting: 1, # TOD: change this to submitted
    approved: 2,
    denied: 3,
    canceled: 4,
    retrieved: 5 # After submitted, updated by impound_record_updates
  }.freeze

  belongs_to :impound_record
  belongs_to :stolen_record
  belongs_to :bike_submitting, class_name: "Bike"
  belongs_to :bike_claimed, class_name: "Bike"
  belongs_to :user
  belongs_to :organization

  has_many :impound_record_updates
  has_many :public_images, as: :imageable, dependent: :destroy
  has_many :notifications, as: :notifiable

  validates_presence_of :impound_record_id, :user_id

  before_validation :set_calculated_attributes
  after_commit :send_triggered_notifications

  enum :status, STATUS_ENUM

  scope :unsubmitted, -> { where(submitted_at: nil) }
  scope :submitted, -> { where.not(submitted_at: nil) }
  scope :active, -> { where(status: active_statuses) }
  scope :resolved, -> { where(status: resolved_statuses) }
  scope :not_rejected, -> { where.not(status: rejected_statuses) }

  attr_accessor :skip_update

  def self.statuses
    STATUS_ENUM.keys.map(&:to_s)
  end

  def self.resolved_statuses
    %w[denied canceled retrieved]
  end

  def self.rejected_statuses
    %w[denied canceled]
  end

  def self.successful_statuses
    %w[approved retrieved]
  end

  def self.active_statuses
    statuses - resolved_statuses
  end

  def self.status_humanized(str)
    # It doesn't make sense to display "submitting"
    (str == "submitting") ? "submitted" : str&.to_s&.tr("_", " ")
  end

  def self.involving_bike_id(bike_id)
    where(bike_submitting_id: bike_id).or(where(bike_claimed_id: bike_id))
  end

  def kind
    # Fallback to impounded
    impound_record&.kind || ImpoundRecord.impounded_kind
  end

  # NOTE: actually cycle_type_name, so I'm ok with not matching cycle_type method name
  def bike_type
    bike_submitting&.type || bike_claimed&.type
  end

  def claim_kind_humanized
    [kind, bike_type, "claim"].reject(&:blank?).join(" ")
  end

  def organized?
    impound_record&.organized? || false
  end

  def resolved?
    self.class.resolved_statuses.include?(status)
  end

  def responded?
    resolved? || approved?
  end

  def active?
    self.class.active_statuses.include?(status)
  end

  def rejected?
    self.class.rejected_statuses.include?(status)
  end

  def successful?
    self.class.successful_statuses.include?(status)
  end

  # Get it not current too, because retrieved notifications
  def stolen_record
    @stolen_record ||= stolen_record_id.present? ? StolenRecord.current_and_not.find_by_id(stolen_record_id) : nil
  end

  # Get it unscoped, because unregistered_bike notifications
  def bike_claimed
    @bike_claimed ||= bike_claimed_id.present? ? Bike.unscoped.find_by_id(bike_claimed_id) : nil
  end

  def status_humanized
    self.class.status_humanized(status)
  end

  # return private images too
  def bike_submitting_images
    return [] unless bike_submitting.present?
    PublicImage.unscoped.where(imageable_id: bike_submitting.id).bike.order(:listing_order)
  end

  def unsubmitted?
    submitted_at.blank?
  end

  def submitted?
    !unsubmitted?
  end

  def impound_record_email
    impound_record.reply_to_email
  end

  def set_calculated_attributes
    self.message = message.blank? ? nil : message.strip
    self.response_message = response_message.blank? ? nil : response_message.strip
    self.status = calculated_status
    self.submitted_at ||= Time.current if status == "submitting"
    self.resolved_at ||= Time.current if resolved?
    self.organization_id ||= impound_record&.organization_id
    # Until the claim is submitted, allow these values to change
    self.bike_submitting = stolen_record&.bike if unsubmitted? || bike_submitting.blank?
    self.bike_claimed = impound_record&.bike if unsubmitted? || bike_claimed.blank?
  end

  def send_triggered_notifications
    return true if skip_update
    EmailImpoundClaimJob.perform_async(id)
  end

  private

  def calculated_status
    return status if impound_record_updates.none?
    last_update = impound_record_updates.reorder(:id).last
    if last_update.claim_approved?
      "approved"
    elsif last_update.claim_denied?
      "denied"
    elsif last_update.retrieved_by_owner?
      "retrieved"
    else # Don't know, so just return existing status
      status
    end
  end
end
