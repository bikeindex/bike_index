# == Schema Information
#
# Table name: recovery_displays
#
#  id               :integer          not null, primary key
#  image            :string(255)
#  link             :string(255)
#  quote            :text
#  quote_by         :string(255)
#  recovered_at     :datetime
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  stolen_record_id :integer
#
# Indexes
#
#  index_recovery_displays_on_stolen_record_id  (stolen_record_id)
#
class RecoveryDisplay < ActiveRecord::Base
  validates_presence_of :quote, :recovered_at
  mount_uploader :image, CircularImageUploader
  process_in_background :image, CarrierWaveProcessWorker
  attr_writer :image_cache
  belongs_to :stolen_record

  default_scope { order("recovered_at desc") }

  attr_accessor :date_input

  before_validation :set_time
  after_commit :update_associations

  def set_time
    if date_input.present?
      self.recovered_at = DateTime.strptime("#{date_input} 06", "%m-%d-%Y %H")
    end
    self.recovered_at = Time.current unless recovered_at.present?
  end

  validate :quote_not_too_long

  def quote_not_too_long
    return true if quote.blank? || quote.length < 301
    errors.add :base, :quote_too_long
  end

  def from_stolen_record(sr_id)
    sr = StolenRecord.current_and_not.where(id: sr_id).first
    return true unless sr.present?
    self.stolen_record = sr
    self.recovered_at = sr.recovered_at
    self.quote = sr.recovered_description
    self.quote_by = calculated_owner_name&.split(/\s/)&.first
  end

  def calculated_owner_name
    return nil unless bike&.current_ownership&.present? && bike&.owner.present?
    bike.owner.name
  end

  def image_processing?
    return false unless image.present? && updated_at > Time.current - 1.minute
    !image_exists?
  end

  def image_exists?
    image.present? && image.file.exists?
  end

  def image_alt
    "Photo of recovered bike"
  end

  def bike
    bike_id = stolen_record&.bike_id
    return nil unless bike_id.present?
    Bike.unscoped.find_by_id(bike_id)
  end

  def stolen_record
    stolen_record_id.present? ? StolenRecord.current_and_not.find_by_id(stolen_record_id) : nil
  end

  def update_associations
    stolen_record&.update(updated_at: Time.current)
  end
end
