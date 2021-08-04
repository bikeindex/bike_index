class Payment < ApplicationRecord
  include Amountable
  PAYMENT_METHOD_ENUM = {stripe: 0, check: 1}.freeze
  KIND_ENUM = {donation: 0, payment: 1, invoice_payment: 2, theft_alert: 3}
  STRIPE_KIND_ENUM = {stripe_charge: 0, stripe_session: 1}

  scope :current, -> { where(is_current: true) }
  scope :subscription, -> { where(is_recurring: true) }
  scope :organizations, -> { where.not(organization_id: nil) }
  scope :non_donation, -> { where.not(kind: "donation") }
  scope :incomplete, -> { where(first_payment_date: nil) }
  scope :paid, -> { where.not(first_payment_date: nil) }

  enum payment_method: PAYMENT_METHOD_ENUM
  enum kind: KIND_ENUM
  enum stripe_kind: STRIPE_KIND_ENUM

  belongs_to :user
  belongs_to :organization
  belongs_to :invoice

  has_one :theft_alert

  has_many :notifications, as: :notifiable

  validate :email_or_organization_present
  validates :currency, presence: true

  before_validation :set_calculated_attributes
  after_commit :update_associations

  def self.payment_methods
    PAYMENT_METHOD_ENUM.keys.map(&:to_s)
  end

  def self.kinds
    KIND_ENUM.keys.map(&:to_s)
  end

  def self.admin_creatable_payment_methods
    ["check"]
  end

  def self.display_kind(kind)
    return "NO KIND!" unless kind.present?
    return "Promoted alert" if kind == "theft_alert"
    kind.humanize
  end

  def paid?
    first_payment_date.present?
  end

  def incomplete?
    !paid?
  end

  def non_donation?
    !donation?
  end

  def display_kind
    self.class.display_kind(kind)
  end

  def stripe_success_url
    if theft_alert?
      "#{ENV["BASE_URL"]}/bikes/#{theft_alert.bike_id}/theft_alerts?session_id={CHECKOUT_SESSION_ID}"
    else
      "#{ENV["BASE_URL"]}/payments/success?session_id={CHECKOUT_SESSION_ID}"
    end
  end

  def stripe_cancel_url
    if theft_alert?
      "#{ENV["BASE_URL"]}/bikes/#{theft_alert&.bike_id}/theft_alerts/new"
    else
      "#{ENV["BASE_URL"]}/payments/new"
    end
  end

  def set_calculated_attributes
    self.kind = calculated_kind
    if user.present?
      self.email ||= user.email
    elsif email.present?
      self.user ||= User.fuzzy_confirmed_or_unconfirmed_email_find(email)
    end
    self.amount_cents ||= theft_alert.amount_cents if theft_alert?
    self.organization_id ||= invoice&.organization_id
  end

  def stripe_session
    return nil unless stripe? && stripe_id.present?
    @stripe_session ||= Stripe::Checkout::Session.retrieve(stripe_id)
  end

  def stripe_customer
    return nil unless stripe_session.present?
    @stripe_customer ||= stripe_session.customer.present? ? Stripe::Customer.retrieve(stripe_session.customer) : nil
  end

  def email_or_organization_present
    return if email.present? || organization_id.present? || stripe_id.present?
    errors.add(:organization, :requires_email_or_org)
    errors.add(:email, :requires_email_or_org)
  end

  def update_associations
    user&.update(skip_update: false, updated_at: Time.current) # Bump user, will create a mailchimp_datum if required
    if payment_method == "stripe" && paid? && email.present?
      EmailReceiptWorker.perform_async(id)
    end
    return true unless invoice.present?
    invoice.update_attributes(updated_at: Time.current) # Manually trigger invoice update
  end

  private

  def calculated_kind
    return "invoice_payment" if invoice_id.present?
    return "theft_alert" if theft_alert.present?
    kind || "donation" # Use the current kind, if it exists
  end
end
