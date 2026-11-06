# == Schema Information
#
# Table name: pos_registration_matches
# Database name: primary
#
#  id                      :bigint           not null, primary key
#  review_reasons          :text             default([]), not null, is an Array
#  status                  :integer          default("pending"), not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  bike_id                 :bigint           not null
#  duplicate_bike_group_id :bigint
#  pos_bike_id             :bigint           not null
#
# Indexes
#
#  index_pos_registration_matches_on_bike_id_and_pos_bike_id  (bike_id,pos_bike_id) UNIQUE
#  index_pos_registration_matches_on_duplicate_bike_group_id  (duplicate_bike_group_id)
#  index_pos_registration_matches_on_pos_bike_id              (pos_bike_id)
#
# A new self-registration of a bike a shop's POS registered to the same owner: a pair within the
# whole-serial DuplicateBikeGroup, recorded by BikeJobs::PosRegistrationMatchFinderJob
class PosRegistrationMatch < ApplicationRecord
  STATUS_ENUM = {pending: 0, confirmed: 1, declined: 2, merged: 3}.freeze
  BUCKETS = %w[merge_candidate review_candidate].freeze
  REVIEW_REASONS = {
    "stolen_history" => "Stolen history on the serial",
    "multiple_pos_bikes" => "More than one POS registration matches",
    "multiple_registrations" => "More than one new registration matches the POS registration",
    "impounded" => "A registration was impounded",
    "marketplace_listing" => "A registration has a marketplace listing",
    "not_a_serial" => "Serial is a part number or placeholder"
  }.freeze

  enum :status, STATUS_ENUM

  belongs_to :duplicate_bike_group
  belongs_to :bike
  belongs_to :pos_bike, class_name: "Bike"

  validates_presence_of :bike_id, :pos_bike_id

  scope :merge_candidate, -> { where(review_reasons: []) }
  scope :review_candidate, -> { where.not(review_reasons: []) }
  scope :with_review_reason, ->(reason) { where("review_reasons @> ARRAY[?]::text[]", reason) }

  # Hidden registrations still match
  def self.live_bike?(bike) = bike.present? && bike.deleted_at.blank? && !bike.example && !bike.likely_spam

  # Stolen history counts any manufacturer's bike with the serial, including deleted and example ones
  def self.review_reasons_for(bike, pos_bike)
    serial = bike.serial_normalized_no_space
    bike_ids = [bike.id, pos_bike.id]
    listings = MarketplaceListing.where(item_type: "Bike", item_id: bike_ids)
      .or(MarketplaceListing.where(item_type: "BikeVersion", item_id: BikeVersion.unscoped.where(bike_id: bike_ids).select(:id)))
    not_a_serial = BikeDuplicatesServices::Cues.not_a_serial(serial,
      manufacturer_names: BikeDuplicatesServices::Cues.fetch_manufacturer_name_serials)
    ordered_reasons([("stolen_history" if BikeDuplicatesServices::Finder.stolen_serials?([serial])),
      ("impounded" if ImpoundRecord.where(bike_id: bike_ids).exists?),
      ("marketplace_listing" if listings.exists?), ("not_a_serial" if not_a_serial)].compact)
  end

  def self.ordered_reasons(reasons) = REVIEW_REASONS.keys & reasons

  def merge_candidate? = review_reasons.none?

  # Reasons are only added, so a recorded stolen veto is never cleared
  def add_review_reasons!(reasons, **attributes)
    update!(review_reasons: self.class.ordered_reasons(review_reasons + reasons), **attributes)
  end

  def bucket = merge_candidate? ? "merge_candidate" : "review_candidate"
end
