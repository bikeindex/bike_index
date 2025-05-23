# == Schema Information
#
# Table name: payments
#
#  id                     :integer          not null, primary key
#  amount_cents           :integer
#  currency_enum          :integer
#  email                  :string(255)
#  kind                   :integer
#  paid_at                :datetime
#  payment_method         :integer          default("stripe")
#  referral_source        :text
#  stripe_status          :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  invoice_id             :integer
#  membership_id          :bigint
#  organization_id        :integer
#  stripe_id              :string(255)
#  stripe_subscription_id :bigint
#  user_id                :integer
#
# Indexes
#
#  index_payments_on_membership_id           (membership_id)
#  index_payments_on_stripe_subscription_id  (stripe_subscription_id)
#  index_payments_on_user_id                 (user_id)
#
class Payment < ApplicationRecord
  include Currencyable
  include Amountable

  PAYMENT_METHOD_ENUM = {stripe: 0, check: 1}.freeze
  KIND_ENUM = {donation: 0, payment: 1, invoice_payment: 2, theft_alert: 3, membership_donation: 4}

  belongs_to :user
  belongs_to :organization
  belongs_to :invoice
  belongs_to :stripe_subscription
  belongs_to :membership

  has_one :theft_alert

  has_many :notifications, as: :notifiable

  enum :payment_method, PAYMENT_METHOD_ENUM
  enum :kind, KIND_ENUM

  scope :organizations, -> { where.not(organization_id: nil) }
  scope :non_donation, -> { where.not(kind: "donation") }
  scope :incomplete, -> { where(paid_at: nil) }
  scope :paid, -> { where.not(paid_at: nil) }

  validate :email_or_organization_or_stripe_present

  before_validation :set_calculated_attributes
  after_commit :update_associations

  attr_accessor :skip_update

  class << self
    def payment_methods
      PAYMENT_METHOD_ENUM.keys.map(&:to_s)
    end

    def kinds
      KIND_ENUM.keys.map(&:to_s)
    end

    def admin_creatable_payment_methods
      ["check"]
    end

    def kind_humanized(kind)
      return "NO KIND!" unless kind.present?
      return "Promoted alert" if kind == "theft_alert"
      kind&.humanize&.gsub("payment", "")&.strip
    end

    def normalize_referral_source(str)
      return nil if str.blank?
      str = str.strip.downcase.gsub(/\A(https:\/\/)?bikeindex.org\W?/, "").gsub(/\/|_/, "-")
      Slugifyer.slugify(str)
    end

    # NOTE: Currently only searches by referral_source - in the future it might do other stuff
    def admin_search(str)
      return all if str.blank?
      where("referral_source ilike ?", "%#{normalize_referral_source(str)}%")
    end
  end

  def paid?
    paid_at.present?
  end

  def incomplete?
    !paid?
  end

  def non_donation?
    !donation?
  end

  def stripe_subscription?
    stripe_subscription_id.present?
  end

  def kind_humanized
    self.class.kind_humanized(kind)
  end

  def stripe_admin_url
    "https://dashboard.stripe.com/payments/#{stripe_id}"
  end

  def stripe_checkout_session(item_name: nil)
    return nil unless stripe?

    @stripe_checkout_session ||= if stripe_id.blank?
      checkout_session = create_stripe_checkout_session(item_name:)
      update(stripe_id: checkout_session.id)
      checkout_session
    else
      Stripe::Checkout::Session.retrieve(stripe_id)
    end
  end

  def session_images
    if %w[donation theft_alert].include?(kind)
      ["https://files.bikeindex.org/uploads/Pu/151203/reg_hance.jpg"]
    else # payment, invoice_payment
      []
    end
  end

  def set_calculated_attributes
    self.kind = calculated_kind
    if user.present?
      self.email ||= user.email
    else
      self.email = EmailNormalizer.normalize(email)
      self.user ||= User.fuzzy_confirmed_or_unconfirmed_email_find(email) if email.present?
    end
    self.amount_cents ||= theft_alert&.amount_cents if theft_alert?
    self.organization_id ||= invoice&.organization_id
    self.membership_id ||= stripe_subscription&.membership_id
    self.referral_source = self.class.normalize_referral_source(referral_source)
  end

  # NOTE: stripe_obj is a stripe checkout session
  def update_from_stripe!(stripe_obj = nil)
    stripe_obj ||= stripe_checkout_session

    self.amount_cents = stripe_obj.amount_total
    # There isn't a paid_at timestamp in the stripe object
    self.paid_at = Time.current if paid_at.blank? && stripe_obj.payment_status == "paid"
    self.stripe_status = stripe_obj.payment_status # TODO - update this
    self.email ||= stripe_email(stripe_obj) if user.blank?
    save!

    if user.present? && user.stripe_id != stripe_obj.customer
      user.update(stripe_id: stripe_obj.customer)
    end
    self
  end

  def can_assign_to_membership?
    return false if stripe_subscription? || theft_alert?

    user_id.present? && membership_id.blank? && invoice_id.blank? && organization_id.blank?
  end

  def can_assign_to_invoice?
    return false if stripe_subscription? || theft_alert? || !paid?

    membership_id.blank?
  end

  def stripe_email(stripe_obj = nil)
    stripe_obj ||= stripe_checkout_session
    return nil unless stripe_obj.present?
    return stripe_obj.customer_email if stripe_obj.customer_email.present?
    if defined?(stripe_obj.customer_details) && stripe_obj.customer_details&.email.present?
      return stripe_obj.customer_details.email
    end

    # Sometimes email isn't in the stripe_checkout_session, and needs to be retrieved
    stripe_customer = Stripe::Customer.retrieve(stripe_obj.customer) if stripe_obj.customer.present?
    stripe_customer&.email
  end

  private

  def email_or_organization_or_stripe_present
    return if email.present? || organization_id.present? || stripe_id.present?
    errors.add(:organization, :requires_email_or_org)
    errors.add(:email, :requires_email_or_org)
  end

  def update_associations
    return if skip_update
    user&.update(skip_update: false, updated_at: Time.current) # Bump user, will create a mailchimp_datum if required
    if stripe? && paid? && email.present? && !theft_alert?
      Email::ReceiptJob.perform_async(id)
    end
    return true unless invoice.present?
    invoice.update(updated_at: Time.current) # Manually trigger invoice update
  end

  def create_stripe_checkout_session(item_name: nil)
    Stripe::Checkout::Session.create(stripe_checkout_session_hash(item_name:))
  rescue Stripe::InvalidRequestError => e
    raise e unless e.message.match?(/no such customer/i)

    # If no such customer, try again without the customer id
    Stripe::Checkout::Session.create(
      stripe_checkout_session_hash(item_name:, user_stripe_hash: {customer_email: user&.email})
    )
  end

  def stripe_checkout_session_hash(item_name: nil, user_stripe_hash: nil)
    user_stripe_hash ||= user_stripe_checkout_session_hash
    if stripe_subscription?
      {
        success_url:,
        cancel_url:,
        mode: "subscription",
        line_items: [{quantity: 1, price: stripe_subscription.stripe_price_stripe_id}]
      }
    else
      item_name ||= kind_humanized
      {
        submit_type: donation? ? "donate" : "pay",
        # payment_method_types: ["card"], # I don't think we actually want to enforce this...
        line_items: [{
          price_data: {
            unit_amount: amount_cents,
            currency: currency_name,
            product_data: {
              name: item_name,
              images: session_images
            }
          },
          quantity: 1
        }],
        mode: "payment",
        success_url:,
        cancel_url:
      }
    end.merge(user_stripe_hash)
  end

  def calculated_kind
    if invoice_id.present?
      "invoice_payment"
    elsif theft_alert.present?
      "theft_alert"
    elsif kind.present?
      kind
    elsif membership_id.present? || stripe_subscription_id.present?
      "membership_donation"
    else
      "donation"
    end
  end

  def success_url
    if theft_alert?
      "#{ENV["BASE_URL"]}/bikes/#{theft_alert&.bike_id}/theft_alert?session_id={CHECKOUT_SESSION_ID}"
    elsif stripe_subscription?
      "#{ENV["BASE_URL"]}/membership/success?session_id={CHECKOUT_SESSION_ID}"
    else
      "#{ENV["BASE_URL"]}/payments/success?session_id={CHECKOUT_SESSION_ID}"
    end
  end

  def cancel_url
    if theft_alert?
      "#{ENV["BASE_URL"]}/bikes/#{theft_alert&.bike_id}/theft_alert/new"
    elsif stripe_subscription?
      "#{ENV["BASE_URL"]}/membership/new"
    else
      "#{ENV["BASE_URL"]}/payments/new"
    end
  end

  def user_stripe_checkout_session_hash
    if user&.stripe_id.present?
      {customer: user.stripe_id}
    else
      email = email.presence || user&.email
      return {} unless email.present?
      {customer_email: user.email}
    end
  end
end
