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
#  stripe_checkout_id     :string
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

  validates_uniqueness_of :stripe_checkout_id, allow_nil: true
  validates_uniqueness_of :stripe_id, allow_nil: true

  delegate :membership_kind, :currency_enum, :interval, :test?, to: :stripe_price, allow_nil: true

  before_validation :set_calculated_attributes

  class << self
    def create_for(stripe_price:, user:, email: nil, stripe_checkout_id: nil)
      # TODO: check if one exists first
      stripe_subscription = new(stripe_price:, user:)
      stripe_subscription.stripe_checkout_session # triggers creating the stripe_checkout_session
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

  def success_url
    "#{ENV["BASE_URL"]}/membership/success?session_id={CHECKOUT_SESSION_ID}"
  end

  def cancel_url
    "#{ENV["BASE_URL"]}/membership/new"
  end

  def stripe_checkout_session
    return @stripe_checkout_session if @stripe_checkout_session.present?

    if stripe_checkout_id.blank?
      @stripe_checkout_session = create_stripe_checkout_session
      update(stripe_checkout_id: @stripe_checkout_session.id)
      @stripe_checkout_session
    else
      @stripe_checkout_session = Stripe::Checkout::Session.retrieve(stripe_checkout_id)
    end
  end

  private

  def set_calculated_attributes
    if @stripe_checkout_session.present?
      self.stripe_status = @stripe_checkout_session.status
      self.stripe_id ||= @stripe_checkout_session.subscription
    end
  end

  # TODO: check first if either of these is instantiated
  def stripe_email
    if @stripe_checkout_session.present?
      return @stripe_checkout_session.email
    end
    stripe_subscription&.email || stripe_checkout_session&.email
  end

  def end_active_user_admin_membership!
    user.membership_active.update(end_at: start_at || Time.current)
    user.reload
  end

  def create_stripe_checkout_session
    Stripe::Checkout::Session.create(stripe_checkout_session_hash)

  rescue Stripe::InvalidRequestError => e
    raise e unless e.message.match?(/no such customer/i)

    # If no such customer, try again without the customer id
    Stripe::Checkout::Session.create(stripe_checkout_session_hash({customer_email: user&.email}))
  end

  def stripe_checkout_session_hash(user_stripe_hash = nil)
    user_stripe_hash ||= user_stripe_session_hash
    {
      success_url:,
      cancel_url:,
      mode: "subscription",
      line_items: [{quantity: 1, price: stripe_price_stripe_id}]
    }.merge(user_stripe_hash)
  end

  def user_stripe_session_hash
    return {} unless email.present?

    user&.stripe_id.present? ? {customer: user.stripe_id} : {customer_email: user.email}
  end
end
