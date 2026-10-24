# == Schema Information
#
# Table name: pos_registration_matches
# Database name: primary
#
#  id          :bigint           not null, primary key
#  status      :integer          default("pending"), not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  bike_id     :bigint           not null
#  pos_bike_id :bigint           not null
#  user_id     :bigint           not null
#
# Indexes
#
#  index_pos_registration_matches_on_bike_id_and_pos_bike_id  (bike_id,pos_bike_id) UNIQUE
#  index_pos_registration_matches_on_pos_bike_id              (pos_bike_id)
#  index_pos_registration_matches_on_user_id                  (user_id)
#
# A new self-registration whose serial and manufacturer match a bike a shop's POS
# registered to the same owner, recorded by BikeJobs::PosRegistrationMatchFinderJob
class PosRegistrationMatch < ApplicationRecord
  STATUS_ENUM = {pending: 0, confirmed: 1, declined: 2, merged: 3}.freeze

  enum :status, STATUS_ENUM

  belongs_to :bike
  belongs_to :pos_bike, class_name: "Bike"
  belongs_to :user

  validates_presence_of :bike_id, :pos_bike_id, :user_id
end
