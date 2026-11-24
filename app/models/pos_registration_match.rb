# == Schema Information
#
# Table name: pos_registration_matches
# Database name: primary
#
#  id                      :bigint           not null, primary key
#  merged_at               :datetime
#  review_reasons          :text             default([]), not null, is an Array
#  status                  :integer          default("pending"), not null
#  token                   :string
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  bike_id                 :bigint           not null
#  duplicate_bike_group_id :bigint
#  merger_id               :bigint
#  pos_bike_id             :bigint           not null
#
# Indexes
#
#  index_pos_registration_matches_on_bike_id_and_pos_bike_id  (bike_id,pos_bike_id) UNIQUE
#  index_pos_registration_matches_on_duplicate_bike_group_id  (duplicate_bike_group_id)
#  index_pos_registration_matches_on_merger_id                (merger_id)
#  index_pos_registration_matches_on_pos_bike_id              (pos_bike_id)
#  index_pos_registration_matches_on_token                    (token) UNIQUE
#
# A new self-registration of a bike a shop's POS registered to the same owner, or to an email that isn't
# theirs: a pair within the whole-serial DuplicateBikeGroup, recorded by BikeJobs::PosRegistrationMatchFinderJob.
# For another email, the token emailed to it says whether to merge, not the owner
class PosRegistrationMatch < ApplicationRecord
  STATUS_ENUM = {pending: 0, confirmed: 1, declined: 2, merged: 3}.freeze
  BUCKETS = %w[merge_candidate review_candidate].freeze
  # The answer page's buttons
  ANSWERS = {"merge" => true, "decline" => false}.freeze
  REVIEW_REASONS = {
    "stolen_history" => "Stolen history on the serial",
    "multiple_pos_bikes" => "More than one POS registration matches",
    "multiple_registrations" => "More than one new registration matches the POS registration",
    "impounded" => "A registration was impounded",
    "marketplace_listing" => "A registration has a marketplace listing",
    "bike_versions" => "A registration has versions",
    "not_a_serial" => "Serial is a part number or placeholder",
    "changed_since_confirmed" => "A registration was edited, removed or transferred after the owner said yes"
  }.freeze

  enum :status, STATUS_ENUM

  belongs_to :duplicate_bike_group
  # Merged matches have a deleted bike, and POS bikes are often hidden. Drops Bike.current from the default
  # scope but keeps its includes, which the admin table reads
  belongs_to :bike, -> { unscope(:order, where: Bike::CURRENT_ATTRIBUTES.keys) }
  belongs_to :pos_bike, -> { unscope(:order, where: Bike::CURRENT_ATTRIBUTES.keys) }, class_name: "Bike"
  # Who said to merge them
  belongs_to :merger, class_name: "User"

  validates_presence_of :bike_id, :pos_bike_id

  scope :merge_candidate, -> { where(review_reasons: []) }
  scope :review_candidate, -> { where.not(review_reasons: []) }
  scope :with_review_reason, ->(reason) { where("review_reasons @> ARRAY[?]::text[]", reason) }

  # Stolen history counts any manufacturer's bike with either serial, including deleted and example ones
  def self.review_reasons_for(bike, pos_bike)
    serial = bike.serial_normalized_no_space
    serials = [serial, pos_bike.serial_normalized_no_space].uniq
    bike_ids = [bike.id, pos_bike.id]
    versions = BikeVersion.unscoped.where(bike_id: bike_ids)
    listings = MarketplaceListing.where(item_type: "Bike", item_id: bike_ids)
      .or(MarketplaceListing.where(item_type: "BikeVersion", item_id: versions.select(:id)))
    not_a_serial = BikeDuplicatesServices::Cues.not_a_serial(serial,
      manufacturer_names: BikeDuplicatesServices::Cues.fetch_manufacturer_name_serials)
    ordered_reasons([("stolen_history" if BikeDuplicatesServices::Finder.stolen_serials?(serials)),
      ("impounded" if ImpoundRecord.where(bike_id: bike_ids).exists?),
      ("marketplace_listing" if listings.exists?),
      ("bike_versions" if versions.exists?), ("not_a_serial" if not_a_serial)].compact)
  end

  def self.ordered_reasons(reasons) = REVIEW_REASONS.keys & reasons

  # Other registrations matched to the same POS registration, which an admin should sort out: live ones, and
  # merged ones, since a registration whose match was recorded after the merge is a third
  def self.other_registration_matches(bike_id:, pos_bike_id:)
    where(pos_bike_id:).where.not(bike_id:).and(where(bike_id: Bike.current_with_user_hidden.select(:id)).or(merged))
  end

  # The shop registered it to the owner's account, or to an address that delivers to one of its emails
  def self.owners_pos_registration?(bike, pos_bike)
    return true if bike.user_id.present? && bike.user_id == pos_bike.user_id

    mailbox = EmailNormalizer.mailbox(pos_bike.current_ownership&.owner_email)
    mailbox.present? && !pos_bike.claimed? && bike.user.present? &&
      bike.user.own_emails.any? { EmailNormalizer.mailbox(it) == mailbox }
  end

  # The registration a deleted one was merged into, so its links still go somewhere
  def self.merged_into(bike) = bike.deleted? ? merged.find_by(bike_id: bike.id)&.pos_bike : nil

  def merge_candidate? = review_reasons.none?

  # The shop registered it to an email that isn't the owner's, so that email is asked, with the token
  def different_email? = token.present?

  # The owner said yes and BikeJobs::MergePosRegistrationJob hasn't run yet
  def merging? = confirmed? && merge_candidate?

  # Whether the owner can still be asked
  def confirmable? = pending? && mergeable?

  # Still the same bike (an edited serial or manufacturer could otherwise slip past the stolen veto), both live,
  # and both theirs - or for another email, the shop's still unclaimed by any account
  def mergeable?
    merge_candidate? && [bike, pos_bike].all? { it&.current_with_user_hidden? } && bike.user_id.present? &&
      (different_email? ? !pos_bike.claimed? : self.class.owners_pos_registration?(bike, pos_bike)) &&
      bike.serial_normalized_no_space == pos_bike.serial_normalized_no_space && bike.manufacturer_id == pos_bike.manufacturer_id
  end

  # Who's asked: the owner, or for another email, that email (and its account, if it has one)
  def asked_user = different_email? ? pos_bike&.user : bike&.user

  def asked_email = different_email? ? pos_bike&.current_ownership&.owner_email : bike&.user&.email

  # The owner, or for another email, whoever has the token emailed to it
  def answerable_by?(user: nil, token: nil)
    return token.present? && ActiveSupport::SecurityUtils.secure_compare(token, self.token) if different_email?

    bike&.user_id.present? && bike.user_id == user&.id
  end

  # The answer (merge is true or false), while one can still be given. Returns whether it was recorded.
  # A yes is rechecked and merged by BikeJobs::MergePosRegistrationJob
  def answer!(merge:, user: nil, token: nil)
    recorded = with_lock do
      next false unless merge.in?([true, false]) && confirmable? && answerable_by?(user:, token:)

      merge ? update!(status: :confirmed, merger: user) : update!(status: :declined)
    end
    # After the lock's transaction commits, so the job finds the match confirmed
    BikeJobs::MergePosRegistrationJob.perform_async(id) if recorded && merge
    recorded
  end

  # Reasons are only added, so a recorded stolen veto is never cleared
  def add_review_reasons!(reasons, **attributes)
    update!(review_reasons: self.class.ordered_reasons(review_reasons + reasons), **attributes)
  end

  def bucket = merge_candidate? ? "merge_candidate" : "review_candidate"
end
