# == Schema Information
#
# Table name: stripe_subscriptions
#
#  id              :bigint           not null, primary key
#  active          :boolean          default(FALSE)
#  end_at          :datetime
#  start_at        :datetime
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  membership_id   :bigint
#  stripe_id       :string
#  stripe_price_id :bigint
#  user_id         :bigint
#
# Indexes
#
#  index_stripe_subscriptions_on_membership_id    (membership_id)
#  index_stripe_subscriptions_on_stripe_price_id  (stripe_price_id)
#  index_stripe_subscriptions_on_user_id          (user_id)
#
class StripeSubscription < ApplicationRecord
  include ActivePeriodable

  belongs_to :membership
  belongs_to :user
  belongs_to :stripe_price, foreign_key: 'stripe_price_stripe_id', primary_key: 'stripe_id'

  has_many :payments

  delegate :membership_kind, to: :stripe_price, allow_nil: true

  def update_membership!
    return unless active?

    end_active_user_admin_membership! if active? && user.membership_active&.admin_managed?

    membership ||= user.membership_active || Membership.new(user_id:)
    membership.update!(start_at:, end_at:, kind: membership_kind)
    update(membership_id: membership.id) if membership_id != membership.id
    membership
  end

  private

  def end_active_user_admin_membership!
    user.membership_active.update(end_at: start_at || Time.current)
    user.reload
  end
end
