class Payment < ActiveRecord::Base
  def self.old_attr_accessible
    %w(user_id email is_current is_recurring stripe_id last_payment_date first_payment_date amount).map(&:to_sym).freeze
  end

  belongs_to :user
  validates_presence_of :email

  before_validation :set_email_from_user
  def set_email_from_user
    return true unless user.present?
    self.email = user.email
  end

  scope :current, -> { where(is_current: true) }
  scope :subscription, -> { where(is_recurring: true) }

  after_create :send_invoice_email
  def send_invoice_email
    EmailInvoiceWorker.perform_async(id)
  end

  def is_donation
    !is_payment
  end
end
