class HotSheet < ApplicationRecord
  belongs_to :organization

  validates_presence_of :organization_id

  after_commit :deliver_hot_sheet

  attr_accessor :skip_update

  scope :email_success, -> { where(delivery_status: "email_success") }

  def self.for(organization, date_or_time)
    date = date_or_time.to_date
    where(organization_id: organization.id).where(created_at: date.beginning_of_day..date.end_of_day).first
  end

  def hot_sheet_configuration; organization.hot_sheet_configuration end

  def bounding_box; hot_sheet_configuration.bounding_box end

  def email_success?; delivery_status == "email_success" end

  # This may become a configurable option
  def max_bikes; 10 end

  def deliver_hot_sheet
    return true if skip_update
    EmailHotSheetWorker.perform_async(id)
  end

  def fetch_stolen_records
    if stolen_record_ids.is_a?(Array)
      return StolenRecord.unscoped.where(id: stolen_record_ids).includes(:bike)
    end
    stolen_records = calculated_stolen_records
    update(skip_update: true, stolen_record_ids: stolen_records.pluck(:id))
    stolen_records
  end

  private

  def calculated_stolen_records
    StolenRecord.current.within_bounding_box(bounding_box).reorder(date_stolen: :desc)
  end
end
