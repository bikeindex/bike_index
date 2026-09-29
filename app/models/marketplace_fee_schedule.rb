# == Schema Information
#
# Table name: marketplace_fee_schedules
# Database name: primary
#
#  id                     :bigint           not null, primary key
#  platform_fee_cap_cents :integer          not null
#  platform_fee_percent   :decimal(5, 2)    not null
#  processing_fee_percent :decimal(5, 2)    not null
#  start_at               :datetime         not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
class MarketplaceFeeSchedule < ApplicationRecord
  # platform_fee_cap_cents is the same number in every currency, not converted from USD
  validates :platform_fee_percent, :processing_fee_percent, numericality: {in: 0..100}
  validates :platform_fee_cap_cents, numericality: {only_integer: true, greater_than_or_equal_to: 0}
  validates_presence_of :start_at
  validates_uniqueness_of :start_at

  # In effect from its start_at until the next row's
  def self.current(time = Time.current) = where(start_at: ..time).order(start_at: :desc).first

  # A new rate is a new row, so the table keeps the fees as they were applied
  def readonly? = super || (persisted? && start_at_in_database <= Time.current)
end
