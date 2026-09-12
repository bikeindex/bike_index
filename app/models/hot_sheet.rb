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
  include EmailDeliveryTrackable

  # Postmark only allows 50 recipients per email, so a day's recipients are split across
  # sheets - all rendering the same bikes
  RECIPIENTS_PER_EMAIL = 48
  MAX_BIKES = 10

  enum :delivery_status, Notification::DELIVERY_STATUS_ENUM

  belongs_to :organization

  has_one :hot_sheet_configuration, through: :organization

  validates_presence_of :organization_id, :sheet_date

  class << self
    # The day's sheets, built (unsaved) one per batch of recipients when the day has none
    def for(organization_or_id, date)
      org_id = organization_or_id.is_a?(Integer) ? organization_or_id : organization_or_id.id
      hot_sheets = where(organization_id: org_id, sheet_date: date).order(:id).to_a
      return hot_sheets if hot_sheets.any?
      # A past day is whatever it was - only today's sheets are still to come
      return [] if date.present? && date != Time.current.to_date

      configuration = HotSheetConfiguration.find_by(organization_id: org_id)
      stolen_record_ids = calculated_stolen_records(configuration).pluck(:id)
      # At least one sheet, so a day with nobody to email is still marked delivered
      (configuration.current_recipient_ids.each_slice(RECIPIENTS_PER_EMAIL).to_a.presence || [[]])
        .map { new(organization_id: org_id, sheet_date: date, recipient_ids: it, stolen_record_ids:) }
    end

    private

    def calculated_stolen_records(hot_sheet_configuration)
      StolenRecord.within_bounding_box(hot_sheet_configuration.bounding_box)
        .reorder(date_stolen: :desc)
        .joins(:bike).where(bikes: {deleted_at: nil})
        .limit(MAX_BIKES)
    end
  end

  def current?
    sheet_date.blank?
  end

  def subject
    "Stolen Bike Hot Sheet: #{sheet_date.strftime("%A, %b %-d")}"
  end

  def recipient_emails
    recipient_users.pluck(:email)
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
    StolenRecord.current_and_not.where(id: stolen_record_ids)
      .reorder(date_stolen: :desc)
      .joins(:bike).where(bikes: {deleted_at: nil}).includes(:bike)
  end

  def recipient_users
    organization.users.where(id: recipient_ids)
  end
end
