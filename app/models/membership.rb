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

  validates :user_id, presence: true
  validate :no_active_stripe_subscription_admin_managed
  before_validation :set_calculated_attributes

  scope :admin_managed, -> { where.not(creator_id: nil) }
  scope :stripe_managed, -> { where(creator_id: nil) }

  attr_accessor :user_email

  def self.kind_humanized(str)
    str&.humanize
  end

  def self.kinds_ordered
    kinds.keys.map { kind_humanized(_1) }
  end

  def kind_humanized
    self.class.kind_humanized(kind)
  end

  def admin_managed?
    creator_id.present?
  end

  def stripe_managed?
    !admin_managed?
  end

  def set_calculated_attributes
    self.kind ||= "basic"
    self.start_at ||= Time.current

    if user_email.present?
      self.user_id ||= User.fuzzy_email_find(user_email)&.id
    end
  end

  def stripe_admin_url
    "Stripe URL"
  end

  private

  def no_active_stripe_subscription_admin_managed
    return if stripe_managed? || !calculated_active? || user.blank?

    active_membership_id = user.memberships.active.order(:id).limit(1).pluck(:id).first
    return if [id, nil].include?(active_membership_id)

    # Currently, the app is not handling cancelling or extending stripe subscriptions
    # So you either have an admin created (and managed) membership, or a stripe subscription
    errors.add(:base, "there is a prior active membership")
  end
end
