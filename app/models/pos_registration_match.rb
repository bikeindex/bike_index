# == Schema Information
#
# Table name: pos_registration_matches
# Database name: primary
#
#  id             :bigint           not null, primary key
#  bucket         :integer          default("merge_candidate"), not null
#  review_reasons :text             default([]), not null, is an Array
#  status         :integer          default("pending"), not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  bike_id        :bigint           not null
#  pos_bike_id    :bigint           not null
#  user_id        :bigint           not null
#
# Indexes
#
#  index_pos_registration_matches_on_bike_id_and_pos_bike_id  (bike_id,pos_bike_id) UNIQUE
#  index_pos_registration_matches_on_pos_bike_id              (pos_bike_id)
#  index_pos_registration_matches_on_user_id                  (user_id)
#
# A new self-registration whose serial and manufacturer match a bike a shop's POS
# registered to the same owner, recorded by BikeJobs::PosRegistrationMatchFinderJob.
# A match with no review reasons is a merge candidate; any reason makes it a review candidate
class PosRegistrationMatch < ApplicationRecord
  STATUS_ENUM = {pending: 0, confirmed: 1, declined: 2, merged: 3}.freeze
  BUCKET_ENUM = {merge_candidate: 0, review_candidate: 1}.freeze
  REVIEW_REASONS = {
    "stolen_history" => "Stolen history on the serial",
    "multiple_pos_bikes" => "More than one POS registration matches",
    "transferred" => "A registration was transferred",
    "impounded" => "A registration was impounded",
    "marketplace_listing" => "A registration has a marketplace listing",
    "not_a_serial" => "Serial is a part number or placeholder"
  }.freeze

  enum :status, STATUS_ENUM
  enum :bucket, BUCKET_ENUM

  belongs_to :bike
  belongs_to :pos_bike, class_name: "Bike"
  belongs_to :user

  validates_presence_of :bike_id, :pos_bike_id, :user_id

  before_validation :set_bucket

  scope :with_review_reason, ->(reason) { where("review_reasons @> ARRAY[?]::text[]", reason) }

  def self.bucket_display(bucket) = bucket.to_s.humanize

  private

  def set_bucket
    self.bucket = review_reasons.any? ? :review_candidate : :merge_candidate
  end
end
