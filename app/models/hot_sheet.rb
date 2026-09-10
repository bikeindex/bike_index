# == Schema Information
#
# Table name: hot_sheets
# Database name: primary
#
#  id                     :bigint           not null, primary key
#  delivery_error         :string
#  delivery_status        :integer          default("delivery_pending")
#  delivery_status_legacy :string
#  recipient_ids          :jsonb
#  sheet_date             :date
#  stolen_record_ids      :jsonb
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  message_id             :string
#  organization_id        :bigint
#
# Indexes
#
#  index_hot_sheets_on_organization_id  (organization_id)
#
class HotSheet < ApplicationRecord
  # A part-delivered batch has no equivalent on Notification, which is one address
  DELIVERY_STATUS_ENUM = {delivery_pending: 0, delivery_success: 1, delivery_failure: 2,
                          delivery_partial_success: 3}.freeze
  DELIVERED_STATUSES = %w[delivery_success delivery_partial_success].freeze
  # Resending a batch every address on it rejected just fails the same way
  UNDELIVERABLE_ERROR_NAMES = Notification::UNDELIVERABLE_ERRORS.map(&:name).freeze

  enum :delivery_status, DELIVERY_STATUS_ENUM

  belongs_to :organization

  has_one :hot_sheet_configuration, through: :organization

  validates_presence_of :organization_id, :sheet_date

  delegate :bounding_box, :timezone, to: :hot_sheet_configuration, allow_nil: true
  scope :delivered, -> { where(delivery_status: DELIVERED_STATUSES) }
  scope :undeliverable, -> { where(delivery_error: UNDELIVERABLE_ERROR_NAMES) }
  scope :settled, -> { delivered.or(undeliverable) }

  def self.for(organization_or_id, date = nil)
    org_id = organization_or_id.is_a?(Integer) ? organization_or_id : organization_or_id.id
    if date.present?
      where(organization_id: org_id, sheet_date: date).first
    else
      new(organization_id: org_id)
    end
  end

  def current?
    sheet_date.blank?
  end

  # A settled batch isn't worth sending again - it delivered, or its addresses are dead
  def settled?
    DELIVERED_STATUSES.include?(delivery_status) || UNDELIVERABLE_ERROR_NAMES.include?(delivery_error)
  end

  # Takes a block. Unlike Notification's, returns the error rather than raising it -
  # the job delivers every batch before blowing up
  def track_email_delivery
    return if settled?

    delivery = yield
    update(delivery_status: "delivery_success", message_id: message_id || delivery.try(:message_id))
    nil
  rescue => e
    record_delivery_failure(e)
    undeliverable_error?(e) ? nil : e
  end

  def subject
    "Stolen Bike Hot Sheet: #{sheet_date.strftime("%A, %b %-d")}"
  end

  def recipient_emails
    fetch_recipients.pluck(:email)
  end

  # This may become a configurable option
  def max_bikes
    10
  end

  def next_sheet
    return nil if current?

    HotSheet.where(organization_id: organization_id).where("sheet_date > ?", sheet_date)
      .reorder(:sheet_date).first
  end

  def previous_sheet
    sdate = current? ? (Time.current.to_date + 1.day) : sheet_date
    HotSheet.where(organization_id: organization_id).where("sheet_date < ?", sdate)
      .reorder(:sheet_date).last
  end

  def fetch_stolen_records
    if stolen_record_ids.is_a?(Array)
      stolen_records = StolenRecord.current_and_not.where(id: stolen_record_ids)
        .reorder(date_stolen: :desc)
    else
      stolen_records = calculated_stolen_records
      update(stolen_record_ids: stolen_records.pluck(:id))
    end
    stolen_records.joins(:bike).where(bikes: {deleted_at: nil})
  end

  def fetch_recipients
    unless recipient_ids.is_a?(Array)
      update(recipient_ids: hot_sheet_configuration.current_recipient_ids)
    end
    organization.users.where(id: recipient_ids)
  end

  private

  # A sheet emails a whole batch at once, so only the addresses Postmark rejected failed
  def record_delivery_failure(error)
    # Postmark delivers to the rest of the batch, whether or not it names who it rejected;
    # any other error leaves no way to tell who received the email
    inactive_recipient_error = error.is_a?(Postmark::InactiveRecipientError)
    failed_emails = inactive_recipient_error ? normalized_emails(error.recipients) : []
    delivered_any = inactive_recipient_error && (recipient_emails - failed_emails).any?
    update(delivery_status: delivered_any ? "delivery_partial_success" : "delivery_failure",
      delivery_error: error.class)
    UserEmail.where(email: failed_emails).each { it.update_last_email_errored!(email_errored: true) }
  end

  def normalized_emails(emails)
    emails.map { EmailNormalizer.normalize(it) }
  end

  def undeliverable_error?(error)
    UNDELIVERABLE_ERROR_NAMES.include?(error.class.name)
  end

  def calculated_stolen_records
    StolenRecord.current.within_bounding_box(bounding_box)
      .reorder(date_stolen: :desc)
      .joins(:bike).where(bikes: {deleted_at: nil})
      .limit(max_bikes)
  end
end
