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
  validates_presence_of :email

  before_validation :set_email_from_user
  after_create :send_invoice_email

  def set_email_from_user
    return true unless user.present?
    self.email = user.email
  end

  def send_invoice_email
    EmailInvoiceWorker.perform_async(id)
  end

  def is_donation
    !is_payment
  end
end
