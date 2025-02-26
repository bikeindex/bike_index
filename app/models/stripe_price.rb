# frozen_string_literal: true

# == Schema Information
#
# Table name: stripe_prices
#
#  id               :bigint           not null, primary key
#  active           :boolean          default(FALSE)
#  amount_cents     :integer
#  currency_enum    :integer
#  interval         :integer
#  live             :boolean          default(FALSE)
#  membership_level :integer
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  stripe_id        :string
#
class StripePrice < ApplicationRecord
  include Amountable
  include Currencyable

  INTERVAL_ENUM = {monthly: 0, yearly: 1}.freeze

  has_many :stripe_subscriptions, foreign_key: "stripe_price_stripe_id", primary_key: "stripe_id"

  enum :membership_level, Membership::LEVEL_ENUM
  enum :interval, INTERVAL_ENUM

  validates :stripe_id, presence: true, uniqueness: true
  validates :currency_enum, presence: true
  validates :membership_level, presence: true
  validates :amount_cents, presence: true
  validates :interval, presence: true

  def self.interval_default
    "monthly"
  end

  def test?
    !live?
  end
end
