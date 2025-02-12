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
#  creator_id :bigint
#  user_id    :bigint
#
# Indexes
#
#  index_memberships_on_creator_id  (creator_id)
#  index_memberships_on_user_id     (user_id)
#
class Membership < ApplicationRecord
  include ActivePeriodable

  KIND_ENUM = {basic: 0, plus: 1, patron: 2}

  belongs_to :user
  belongs_to :creator, class_name: "User"

  has_many :stripe_subscriptions
  # has_one :active_stripe_subscription, stripe_subscriptions.active
  has_many :payments, through: :stripe_subscriptions

  enum :kind, KIND_ENUM

  validate :no_active_stripe_subscription_admin_managed, on: :create
  before_validation :set_calculated_attributes

  scope :admin_managed, -> { where.not(creator_id: nil) }
  scope :stripe_managed, -> { where(creator_id: nil) }

  def admin_managed?
    creator_id.present?
  end

  def stripe_managed?
    !admin_managed?
  end

  def no_active_stripe_subscription_admin_managed
    return if stripe_managed? || user.membership_active.blank?

    # Currently, the app is not handling cancelling or extending stripe subscriptions
    # So you either have an admin created (and managed) membership, or a stripe subscription
    errors.add(:base, "can't create because there is already an active membership")
  end

  def set_calculated_attributes
    self.kind ||= "basic"
  end
end
