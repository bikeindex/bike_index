# == Schema Information
#
# Table name: stripe_prices
#
#  id              :bigint           not null, primary key
#  interval        :integer
#  membership_kind :integer
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  stripe_id       :string
#
class StripePrice < ApplicationRecord

  has_many :stripe_subscriptions

  enum :membership_kind, Mebership::KIND_ENUM
end
