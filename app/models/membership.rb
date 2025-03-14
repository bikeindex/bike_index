# == Schema Information
#
# Table name: memberships
#
#  id         :bigint           not null, primary key
#  end_at     :datetime
#  level      :integer
#  start_at   :datetime
#  status     :integer
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
  include StatusHumanizable

  LEVEL_ENUM = {basic: 0, plus: 1, patron: 2}
  STATUS_ENUM = {pending: 0, active: 1, ended: 2}

  belongs_to :user
  belongs_to :creator, class_name: "User"

  has_many :stripe_subscriptions
  has_many :payments

  enum :level, LEVEL_ENUM
  enum :status, STATUS_ENUM

  validate :no_current_stripe_subscription_admin_managed
  before_validation :set_calculated_attributes

  scope :admin_managed, -> { where.not(creator_id: nil) }
  scope :stripe_managed, -> { where(creator_id: nil) }

  delegate :stripe_id, :stripe_portal_session, :stripe_admin_url,
    to: :current_stripe_subscription, allow_nil: true

  attr_accessor :user_email, :set_interval

  class << self
    def level_humanized(str)
      str&.humanize
    end

    def levels_ordered
      levels.keys.map { level_humanized(_1) }
    end
  end

  def current_stripe_subscription
    return @current_stripe_subscription if defined?(@current_stripe_subscription)

    subscriptions = stripe_subscriptions.order(:id)
    @current_stripe_subscription = subscriptions.active.first || subscriptions.last
  end

  def level_humanized
    self.class.level_humanized(level)
  end

  def admin_managed?
    creator_id.present?
  end

  def stripe_managed?
    !admin_managed?
  end

  def update_from_stripe!
    unless stripe_managed? && current_stripe_subscription.present?
      raise "Must have a current_stripe_subscription to be able to update from Stripe!"
    end

    current_stripe_subscription.update_from_stripe!
  end

  def referral_source
    current_stripe_subscription&.referral_source || payments.order(:id).first&.referral_source
  end

  def set_calculated_attributes
    self.level ||= "basic"
    self.status = calculated_status

    if user_email.present?
      self.user_id ||= User.fuzzy_email_find(user_email)&.id
    end
  end

  def interval
    current_stripe_subscription&.interval
  end

  private

  def calculated_status
    if start_at.blank? || start_at > Time.current + 1.minute
      "pending"
    elsif period_active?
      "active"
    else
      "ended"
    end
  end

  def no_current_stripe_subscription_admin_managed
    return if stripe_managed? || period_inactive? || user.blank?
    active_membership_id = user.memberships.active.order(:id).limit(1).pluck(:id).first
    return if [id, nil].include?(active_membership_id)

    # Currently, the app is not handling cancelling or extending stripe subscriptions
    # So you either have an admin created (and managed) membership, or a stripe subscription
    errors.add(:base, "there is a prior active membership")
  end
end
