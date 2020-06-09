class HotSheet < ApplicationRecord
  belongs_to :organization

  validates_presence_of :organization_id

  after_commit :deliver_hot_sheet

  attr_accessor :skip_update

  scope :email_success, -> { where(delivery_status: "email_success") }

  # t.references :organization
  # t.jsonb :stolen_record_ids
  # t.jsonb :recipients
  # t.string :delivery_status

  def self.for(organization, date_or_time)
    date = date_or_time.to_date
    where(organization_id: organization.id).where(created_at: date.beginning_of_day..date.end_of_day).first
  end

  def email_success?; delivery_status == "email_success" end

  def deliver_hot_sheet
    return true if skip_update
    EmailHotSheetWorker.perform_async(id)
  end

  def fetch_stolen_records
    if stolen_record_ids.is_a?(Array)
      return StolenRecord.unscoped.where(id: stolen_record_ids).includes(:bike)
    end
  end
end
