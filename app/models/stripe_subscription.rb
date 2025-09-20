# == Schema Information
#
# Table name: stripe_subscriptions
#
#  id                     :bigint           not null, primary key
#  end_at                 :datetime
#  referral_source        :text
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
  include ActivePeriodable

  belongs_to :membership
  belongs_to :user
  belongs_to :stripe_price, foreign_key: "stripe_price_stripe_id", primary_key: "stripe_id"

  has_many :payments
  has_many :stripe_events, foreign_key: "stripe_subscription_stripe_id", primary_key: "stripe_id"

  validates :stripe_id, uniqueness: {allow_nil: true}

  before_validation :set_calculated_attributes

  scope :active, -> { where(stripe_status: "active") }

  delegate :membership_level, :currency_enum, :interval, :test?, to: :stripe_price, allow_nil: true

  class << self
    def create_for(stripe_price:, user:, referral_source: nil)
      # TODO: check if one exists first
      stripe_subscription = create(stripe_price:, user:, referral_source:)
      stripe_subscription.fetch_stripe_checkout_session_url # triggers creating the stripe_checkout_session
      stripe_subscription
    end

    def create_or_update_from_stripe!(stripe_subscription_obj:, stripe_checkout_session: nil)
      stripe_subscription = find_by(stripe_id: stripe_subscription_obj.id)
      # Get the subscription by looking up the payment
      if stripe_subscription.blank? && stripe_checkout_session.present?
        stripe_subscription = Payment.find_by(stripe_id: stripe_checkout_session.id)&.stripe_subscription
      end
      stripe_subscription ||= new(stripe_id: stripe_subscription_obj.id)

      stripe_subscription.update_from_stripe!(stripe_subscription_obj, skip_membership_update: true)
      if stripe_checkout_session.present?
        stripe_subscription.find_or_create_payment(stripe_checkout_session)
      end
      stripe_subscription.update_membership!

      stripe_subscription
    end
  end

  def active?
    stripe_status == "active"
  end

  def update_membership!
    return unless user_id.present?

    if active?
      end_active_user_admin_membership!

      self.membership ||= user&.membership_active
      self.membership&.level = membership_level
    end
    self.membership ||= Membership.new(user_id:, level: membership_level)
    self.membership&.update!(start_at:, end_at:)

    if membership&.id&.present? && membership_id != membership.id
      update(membership_id: membership.id)
      payments.where(membership_id: nil).each { |payment| payment.update(membership_id:) }
    end
    membership
  end

  def update_from_stripe!(stripe_obj = nil, skip_membership_update: false)
    stripe_obj ||= fetch_stripe_subscription_obj
    raise "Unable to find subscription" unless stripe_obj.present?

    self.stripe_id ||= stripe_obj.id
    self.user_id ||= User.find_by(stripe_id: stripe_obj.customer)&.id
    self.stripe_status = stripe_obj.status

    new_stripe_price_stripe_id = stripe_obj.plan["id"]
    self.stripe_price_stripe_id = new_stripe_price_stripe_id if new_stripe_price_stripe_id.present?

    start_at_t = stripe_obj.start_date
    self.start_at = Time.at(start_at_t) if start_at_t.present?

    end_at_t = stripe_obj.ended_at || stripe_obj.cancel_at
    self.end_at = Time.at(end_at_t) if end_at_t.present?
    save!
    update_membership! unless skip_membership_update
    self
  end

  def email
    user&.email || payments.first&.email
  end

  def stripe_admin_url
    "https://dashboard.stripe.com/subscriptions/#{stripe_id}"
  end

  def stripe_checkout_session_url
    @stripe_checkout_session_url || fetch_stripe_checkout_session_url
  end

  def fetch_stripe_checkout_session_url
    return @stripe_checkout_session_url if @stripe_checkout_session_url.present?

    payment = payments.order(:id).first ||
      payments.create(payment_attrs)

    @stripe_checkout_session_url = payment.stripe_checkout_session.url
  end

  def find_or_create_payment(stripe_checkout_session, referral_source: nil)
    payment = payments.find_by(stripe_id: stripe_checkout_session.id) ||
      payments.build(payment_attrs.merge(stripe_id: stripe_checkout_session.id, referral_source:))

    payment.update_from_stripe!(stripe_checkout_session)
    update(user_id: payment.user_id) if user_id.blank? && payment.user_id.present?

    payment
  end

  def stripe_portal_session
    Stripe::BillingPortal::Session.create({
      customer: user&.stripe_id,
      return_url: "#{ENV["BASE_URL"]}/my_account"
    })
  end

  private

  def payment_attrs
    {payment_method: "stripe", amount_cents: stripe_price&.amount_cents, currency_enum:, user_id:,
     referral_source:}
  end

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
    return unless user.membership_active&.admin_managed?

    user.membership_active.update(end_at: start_at || Time.current)
    user.reload
  end
end
