# == Schema Information
#
# Table name: stripe_subscriptions
#
#  id                     :bigint           not null, primary key
#  end_at                 :datetime
#  start_at               :datetime
#  stripe_status          :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  membership_id          :bigint
#  stripe_id              :string
#  stripe_price_stripe_id :string
#  user_id                :bigint
#
# Indexes
#
#  index_stripe_subscriptions_on_membership_id           (membership_id)
#  index_stripe_subscriptions_on_stripe_price_stripe_id  (stripe_price_stripe_id)
#  index_stripe_subscriptions_on_user_id                 (user_id)
#
class StripeSubscription < ApplicationRecord
  belongs_to :membership
  belongs_to :user
  belongs_to :stripe_price, foreign_key: "stripe_price_stripe_id", primary_key: "stripe_id"

  has_many :payments
  has_many :stripe_events, foreign_key: "stripe_subscription_stripe_id", primary_key: "stripe_id"

  validates_uniqueness_of :stripe_id, allow_nil: true

  delegate :membership_kind, :currency_enum, :interval, :test?, to: :stripe_price, allow_nil: true

  before_validation :set_calculated_attributes

  class << self
    def create_for(stripe_price:, user:)
      # TODO: check if one exists first
      stripe_subscription = create(stripe_price:, user:)
      stripe_subscription.fetch_stripe_checkout_session_url # triggers creating the stripe_checkout_session
      stripe_subscription
    end

    def find_or_create_from_stripe(stripe_subscription_obj:, stripe_checkout_session: nil)
      stripe_subscription = find_by(stripe_id: stripe_subscription_obj.id) || new(stripe_id: stripe_subscription_obj.id)
      stripe_subscription.update_from_stripe_subscription!(stripe_subscription_obj)
      if stripe_checkout_session.present?
        stripe_subscription.find_or_create_payment(stripe_checkout_session)
      end
      stripe_subscription
    end
  end

  def active?
    stripe_status == "active"
  end

  def update_membership!
    return unless active? && user_id.present?

    end_active_user_admin_membership! if active? && user&.membership_active&.admin_managed?

    membership ||= user&.membership_active || Membership.new(user_id:)
    membership.update!(start_at:, end_at:, kind: membership_kind)
    update(membership_id: membership.id) if membership_id != membership.id
    membership
  end

  def update_from_stripe_subscription!(stripe_obj = nil)
    stripe_obj ||= fetch_stripe_subscription_obj
    raise "Unable to find subscription" unless stripe_obj.present?

    self.stripe_status = stripe_obj.status

    new_stripe_price_stripe_id = stripe_obj.plan&.id
    self.stripe_price_stripe_id = new_stripe_price_stripe_id if new_stripe_price_stripe_id.present?

    start_at_t = stripe_obj.start_date
    self.start_at = Time.at(start_at_t) if start_at_t.present?

    # TODO: Verify this is what we want (not cancel_at, etc)
    end_at_t = stripe_obj.ended_at
    self.end_at = Time.at(end_at_t) if end_at_t.present?
    save!
  end

  def email
    user&.email || payments.first&.email
  end

  def stripe_checkout_session_url
    @stripe_checkout_session_url || fetch_stripe_checkout_session_url
  end

  def fetch_stripe_checkout_session_url
    return @stripe_checkout_session_url if @stripe_checkout_session_url.present?

    payment = payments.order(:id).first ||
      payments.create(payment_method: :stripe, currency_enum:, user_id:)

    @stripe_checkout_session_url = payment.stripe_checkout_session.url
  end

  def find_or_create_payment(stripe_checkout_session)
    payment = payments.find_by(stripe_id: stripe_checkout_session.id) ||
      payments.build(payment_method: :stripe, currency_enum:, user_id:, stripe_id: stripe_checkout_session.id)

    payment.update_from_stripe_checkout_session!(stripe_checkout_session)
  end

  private

  def fetch_stripe_subscription_obj
    return nil if stripe_id.blank?

    @stripe_subscription_obj ||= Stripe::Subscription.retrieve(stripe_id)
  end

  def set_calculated_attributes
    if @stripe_checkout_session.present?
      self.stripe_status = @stripe_checkout_session.status
      self.stripe_id ||= @stripe_checkout_session.subscription
    end
  end

  def end_active_user_admin_membership!
    user.membership_active.update(end_at: start_at || Time.current)
    user.reload
  end
end
