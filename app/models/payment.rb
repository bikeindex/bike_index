class Payment < ApplicationRecord
  include Amountable
  PAYMENT_METHOD_ENUM = { stripe: 0, check: 1 }.freeze
  KIND_ENUM = { donation: 0, payment: 1, invoice_payment: 2, theft_alert: 3 }

  scope :current, -> { where(is_current: true) }
  scope :subscription, -> { where(is_recurring: true) }
  scope :organizations, -> { where.not(organization_id: nil) }
  scope :non_donation, -> { where.not(kind: "donation") }

  enum payment_method: PAYMENT_METHOD_ENUM
  enum kind: KIND_ENUM

  belongs_to :user
  belongs_to :organization
  belongs_to :invoice
  has_one :theft_alert

  validate :email_or_organization_present
  validates :currency, presence: true

  before_validation :set_calculated_attributes
  after_create :send_invoice_email
  after_commit :update_invoice

  def self.payment_methods; PAYMENT_METHOD_ENUM.keys.map(&:to_s) end

  def self.kinds; KIND_ENUM.keys.map(&:to_s) end

  def self.admin_creatable_payment_methods; ["check"] end

  def self.display_kind(kind)
    return "NO KIND!" unless kind.present?
    return "Promoted alert" if kind == "theft_alert"
    kind.humanize
  end

  def non_donation?; !donation? end

  def display_kind; self.class.display_kind(kind) end

  def set_calculated_attributes
    self.kind = calculated_kind
    if user.present?
      self.email ||= user.email
    elsif email.present?
      self.user ||= User.fuzzy_confirmed_or_unconfirmed_email_find(email)
    end
  end

  def send_invoice_email
    EmailInvoiceWorker.perform_async(id) if payment_method == "stripe"
  end

  def email_or_organization_present
    return if email.present? || organization_id.present?
    errors.add(:organization, :requires_email_or_org)
    errors.add(:email, :requires_email_or_org)
  end

  def update_invoice
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
