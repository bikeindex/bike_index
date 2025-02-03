# == Schema Information
#
# Table name: payments
#
#  id              :integer          not null, primary key
#  amount_cents    :integer
#  currency        :string           default("USD"), not null
#  email           :string(255)
#  kind            :integer
#  paid_at         :datetime
#  payment_method  :integer          default("stripe")
#  referral_source :text
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  invoice_id      :integer
#  organization_id :integer
#  stripe_id       :string(255)
#  user_id         :integer
#
class Payment < ApplicationRecord
  include Amountable
  PAYMENT_METHOD_ENUM = {stripe: 0, check: 1}.freeze
  KIND_ENUM = {donation: 0, payment: 1, invoice_payment: 2, theft_alert: 3}

  scope :organizations, -> { where.not(organization_id: nil) }
  scope :non_donation, -> { where.not(kind: "donation") }
  scope :incomplete, -> { where(paid_at: nil) }
  scope :paid, -> { where.not(paid_at: nil) }

  enum :payment_method, PAYMENT_METHOD_ENUM
  enum :kind, KIND_ENUM

  belongs_to :user
  belongs_to :organization
  belongs_to :invoice

  has_one :theft_alert

  has_many :notifications, as: :notifiable

  validate :email_or_organization_present
  validates :currency, presence: true

  before_validation :set_calculated_attributes
  after_commit :update_associations

  attr_accessor :skip_update

  def self.payment_methods
    PAYMENT_METHOD_ENUM.keys.map(&:to_s)
  end

  def self.kinds
    KIND_ENUM.keys.map(&:to_s)
  end

  def self.admin_creatable_payment_methods
    ["check"]
  end

  def self.kind_humanized(kind)
    return "NO KIND!" unless kind.present?
    return "Promoted alert" if kind == "theft_alert"
    kind&.humanize
  end

  def self.normalize_referral_source(str)
    return nil if str.blank?
    str = str.strip.downcase.gsub(/\A(https:\/\/)?bikeindex.org\W?/, "").gsub(/\/|_/, "-")
    Slugifyer.slugify(str)
  end

  # NOTE: Currently only searches by referral_source - in the future it might do other stuff
  def self.admin_search(str)
    return all if str.blank?
    where("referral_source ilike ?", "%#{normalize_referral_source(str)}%")
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

  def kind_humanized
    self.class.kind_humanized(kind)
  end

  def stripe_session_hash(item_name: nil)
    item_name ||= kind_humanized
    {
      submit_type: donation? ? "donate" : "pay",
      payment_method_types: ["card"],
      line_items: [{
        price_data: {
          unit_amount: amount_cents,
          currency: currency,
          product_data: {
            name: item_name,
            images: session_images
          }
        },
        quantity: 1
      }],
      mode: "payment",
      success_url: stripe_success_url,
      cancel_url: stripe_cancel_url
    }.merge(user_stripe_session_hash)
  end

  def session_images
    if %w[donation theft_alert].include?(kind)
      ["https://files.bikeindex.org/uploads/Pu/151203/reg_hance.jpg"]
    else # payment, invoice_payment
      []
    end
  end

  def stripe_success_url
    if theft_alert?
      "#{ENV["BASE_URL"]}/bikes/#{theft_alert&.bike_id}/theft_alert?session_id={CHECKOUT_SESSION_ID}"
    else
      "#{ENV["BASE_URL"]}/payments/success?session_id={CHECKOUT_SESSION_ID}"
    end
  end

  def stripe_cancel_url
    if theft_alert?
      "#{ENV["BASE_URL"]}/bikes/#{theft_alert&.bike_id}/theft_alert/new"
    else
      "#{ENV["BASE_URL"]}/payments/new"
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
    self.referral_source = self.class.normalize_referral_source(referral_source)
  end

  def stripe_session
    return nil unless stripe? && stripe_id.present?
    @stripe_session ||= Stripe::Checkout::Session.retrieve(stripe_id)
  end

  # Right now, this method is only good for updating unpaid payments to be paid, when stripe says they are paid
  def update_from_stripe_session
    return unless incomplete? && stripe_session.payment_status == "paid"
    update(paid_at: Time.current,
      amount_cents: stripe_session.amount_total)
    # Update email if we can
    return unless stripe_customer.present?
    update(email: stripe_customer.email)
    if user.present? && user.stripe_id.blank?
      user.update(stripe_id: stripe_customer.id)
    end
    true
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
    return if skip_update
    user&.update(skip_update: false, updated_at: Time.current) # Bump user, will create a mailchimp_datum if required
    if stripe? && paid? && email.present? && !theft_alert?
      EmailReceiptWorker.perform_async(id)
    end
    return true unless invoice.present?
    invoice.update(updated_at: Time.current) # Manually trigger invoice update
  end

  private

  def calculated_kind
    return "invoice_payment" if invoice_id.present?
    return "theft_alert" if theft_alert.present?
    kind || "donation" # Use the current kind, if it exists
  end

  def user_stripe_session_hash
    if user&.stripe_id.present?
      {customer: user.stripe_id}
    else
      email = email.presence || user&.email
      return {} unless email.present?
      {customer_email: user.email}
    end
  end
end
