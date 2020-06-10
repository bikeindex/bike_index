class HotSheet < ApplicationRecord
  belongs_to :organization

  validates_presence_of :organization_id

  scope :email_success, -> { where(delivery_status: "email_success") }

  def self.for(organization_or_id, date_or_time)
    org_id = organization_or_id.is_a?(Integer) ? organization_or_id : organization_or_id.id
    date = date_or_time.to_date
    where(organization_id: org_id).where(created_at: date.beginning_of_day..date.end_of_day).first
  end

  def hot_sheet_configuration; organization.hot_sheet_configuration end

  def bounding_box; hot_sheet_configuration.bounding_box end

  def timezone; hot_sheet_configuration.timezone end

  def email_success?; delivery_status == "email_success" end

  def subject; "Hot Sheet #{sheet_date.strftime("%A, %b %-d")}" end

  # This may become a configurable option
  def max_bikes; 10 end

  # This will use the timezone sometime
  def sheet_date
    created_at.in_time_zone(timezone).to_date
  end

  def fetch_stolen_records
    if stolen_record_ids.is_a?(Array)
      return StolenRecord.unscoped.where(id: stolen_record_ids).includes(:bike)
    end
    stolen_records = calculated_stolen_records
    update(stolen_record_ids: stolen_records.pluck(:id))
    stolen_records
  end

  def fetch_recipients
    fail # not yet implemented
  end

  def deliver_email
    # This is called from process_hot_sheet_worker, so it can be delivered now
    OrganizedMailer.hot_sheet(self).deliver_now
    update(delivery_status: "email_success")
  end

  private

  def calculated_stolen_records
    StolenRecord.current.within_bounding_box(bounding_box).reorder(date_stolen: :desc)
  end
end
