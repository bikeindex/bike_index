class Payment < ActiveRecord::Base
  include Amountable
  KIND_ENUM = { stripe: 0, check: 1 }.freeze

  scope :current, -> { where(is_current: true) }
  scope :subscription, -> { where(is_recurring: true) }
  scope :organizations, -> { where.not(organization_id: nil) }
  scope :stripe, -> { where.not(stripe_id: nil) }
  scope :check, -> { where(is_check: true) }

  enum kind: KIND_ENUM

  belongs_to :user
  belongs_to :organization
  belongs_to :invoice
  validate :email_or_organization_present

  before_validation :set_calculated_attributes
  after_create :send_invoice_email

  def set_calculated_attributes
    if user.present?
      self.email ||= user.email
    elsif email.present?
      self.user ||= User.fuzzy_confirmed_or_unconfirmed_email_find(email)
    end
  end

  def send_invoice_email
    EmailInvoiceWorker.perform_async(id) if kind == "stripe"
  end

  def is_donation
    !is_payment
  end

  def email_or_organization_present
    errors.add(:organization_or_email, "Requires an email address or organization") unless email.present? || organization_id.present?
  end
end
