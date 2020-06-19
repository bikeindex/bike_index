class HotSheet < ApplicationRecord
  belongs_to :organization

  has_one :hot_sheet_configuration, through: :organization

  validates_presence_of :organization_id, :sheet_date

  scope :email_success, -> { where(delivery_status: "email_success") }

  def self.for(organization_or_id, date = nil)
    org_id = organization_or_id.is_a?(Integer) ? organization_or_id : organization_or_id.id
    if date.present?
      where(organization_id: org_id, sheet_date: date).first
    else
      new(organization_id: org_id)
    end
  end

  delegate :bounding_box, :timezone, to: :hot_sheet_configuration, allow_nil: true

  def current?; sheet_date.blank? end

  def email_success?; delivery_status == "email_success" end

  def subject; "Stolen Bike Hot Sheet: #{sheet_date.strftime("%A, %b %-d")}" end

  def recipient_emails; fetch_recipients.pluck(:email) end

  # This may become a configurable option
  def max_bikes; 10 end

  def next_sheet
    return nil if current?
    HotSheet.where(organization_id: organization_id, sheet_date: sheet_date + 1.day).first
  end

  def previous_sheet
    prev_date = current? ? Time.current.to_date : (sheet_date - 1.day)
    HotSheet.where(organization_id: organization_id, sheet_date: prev_date).first
  end

  def fetch_stolen_records
    if stolen_record_ids.is_a?(Array)
      stolen_records = StolenRecord.unscoped.where(id: stolen_record_ids)
                                   .reorder(date_stolen: :desc)
    else
      stolen_records = calculated_stolen_records
      update(stolen_record_ids: stolen_records.pluck(:id))
    end
    stolen_records.joins(:bike).where(bikes: { deleted_at: nil })
  end

  def fetch_recipients
    unless recipient_ids.is_a?(Array)
      update(recipient_ids: hot_sheet_configuration.current_recipient_ids)
    end
    organization.users.where(id: recipient_ids)
  end

  def deliver_email
    # This is called from process_hot_sheet_worker, so it can be delivered inline
    OrganizedMailer.hot_sheet(self).deliver_now
    update(delivery_status: "email_success")
  end

  private

  def calculated_stolen_records
    StolenRecord.current.within_bounding_box(bounding_box)
                .reorder(date_stolen: :desc)
                .joins(:bike).where(bikes: { deleted_at: nil })
                .limit(max_bikes)
  end
end
