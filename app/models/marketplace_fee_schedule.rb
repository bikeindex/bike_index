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
  # Starting in the past would change the fees for times that have already been charged
  validates :start_at, comparison: {greater_than: -> { Time.current }, message: "must be in the future"}, allow_nil: true, if: :will_save_change_to_start_at?

  # The zone start_at is read in, since the admin form's datetime field has none. Assign it before start_at
  attr_accessor :timezone

  # In effect from its start_at until the next row's
  def self.current(time = Time.current) = where(start_at: ..time).order(start_at: :desc).first

  # A new rate is a new row, so the table keeps the fees as they were applied
  def readonly? = super || (persisted? && start_at_in_database <= Time.current)

  def start_at=(val)
    super(Binxtils::TimeParser.parse(val, timezone, parse_error: :nil))
  end

  # The cap in dollars, which is how the admin form takes it
  def platform_fee_cap
    return if platform_fee_cap_cents.nil?

    dollars = platform_fee_cap_cents / 100.0
    (dollars % 1 == 0) ? dollars.to_i : dollars
  end

  def platform_fee_cap=(val)
    self.platform_fee_cap_cents = Amountable.to_cents(val)
  end
end
