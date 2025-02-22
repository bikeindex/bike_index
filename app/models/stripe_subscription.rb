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

    # Called from the webhook. But don't rely on data from webhook, in case it's stale. re-request it
    def find_or_create_from_stripe(stripe_checkout: nil, stripe_subscription_obj: nil)
      if stripe_checkout.present?
        stripe_subscription = StripeSubscription.find_by(stripe_checkout_id: stripe_checkout.id)
        stripe_subscription ||= StripeSubscription.create(stripe_checkout_id: stripe_checkout.id)
        stripe_subscription.update_from_stripe!
      end
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

  def update_from_stripe!
    if stripe_id.blank?
      pp stripe_checkout_session
    else
    end
  end

  # Might be pulling this from stripe sometime...
  def email
    user&.email || stripe_email
  end

  def stripe_checkout_session_url
    @stripe_checkout_session_url
  end

  def fetch_stripe_checkout_session_url
    return @stripe_checkout_session_url if @stripe_checkout_session_url.present?

    payment = payments.order(:id).first ||
     payments.create(payment_method: :stripe, currency_enum:, user_id:)

    @stripe_checkout_session_url = payment.stripe_checkout_session.url
    # return @stripe_checkout_session if @stripe_checkout_session.present?

    # if stripe_checkout_id.blank?
    #   @stripe_checkout_session = create_stripe_checkout_session
    #   update(stripe_checkout_id: @stripe_checkout_session.id)
    #   @stripe_checkout_session
    # else
    #   @stripe_checkout_session = Stripe::Checkout::Session.retrieve(stripe_checkout_id)
    # end
  end

  private

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

  # def user_stripe_session_hash
  #   return {} unless email.present?

  #   user&.stripe_id.present? ? {customer: user.stripe_id} : {customer_email: user.email}
  # end
end
