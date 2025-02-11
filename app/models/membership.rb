# == Schema Information
#
# Table name: memberships
#
#  id         :bigint           not null, primary key
#  active     :boolean          default(FALSE)
#  end_at     :datetime
#  kind       :integer
#  start_at   :datetime
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :bigint
#
# Indexes
#
#  index_memberships_on_user_id  (user_id)
#
class Membership < ApplicationRecord
  include ActivePeriodable

  KIND_ENUM = {basic: 0, plus: 1, patron: 2}

  belongs_to :user
  has_many :stripe_subscriptions
  # has_one :active_stripe_subscription, stripe_subscriptions.active
  has_many :payments, through: :stripe_subscriptions

  enum :kind, KIND_ENUM
end
