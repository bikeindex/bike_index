# == Schema Information
#
# Table name: recovery_displays
# Database name: primary
#
#  id               :integer          not null, primary key
#  link             :string(255)
#  location_string  :string
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
  belongs_to :stolen_record

  has_one_attached :photo
  has_one_attached :photo_processed

  after_commit :enqueue_photo_processing, if: :persisted?

  attr_accessor :date_input, :remote_photo_url, :skip_callback_job

  validates_presence_of :quote, :recovered_at
  validate :quote_not_too_long

  before_validation :set_calculated_attributes

  default_scope { order("recovered_at desc") }

  class << self
    def from_stolen_record_id(id)
      stolen_record = StolenRecord.current_and_not.where(id:).first
      return new unless stolen_record.present?

      new_record = new(attributes_from_stolen_record(stolen_record))
      new_record.set_calculated_attributes
      new_record
    end

    def attributes_from_stolen_record(stolen_record)
      bike = Bike.unscoped.find_by_id(stolen_record.bike_id) if stolen_record.bike_id.present?

      {
        stolen_record:,
        recovered_at: stolen_record.recovered_at,
        location_string: stolen_record.city,
        quote: stolen_record.recovered_description,
        quote_by: calculated_owner_name(bike)&.split(/\s/)&.first
      }
    end

    def calculated_owner_name(bike)
      return unless bike&.current_ownership&.present? && bike&.owner.present?

      bike.owner.name
    end
  end

  def set_calculated_attributes
    if date_input.present?
      self.recovered_at = DateTime.strptime("#{date_input} 06", "%m-%d-%Y %H")
    end
    self.recovered_at = Time.current unless recovered_at.present?
    self.link = Binxtils::InputNormalizer.string(link)
    self.location_string = Binxtils::InputNormalizer.string(location_string)
    self.quote = Binxtils::InputNormalizer.string(quote)
    self.quote_by = Binxtils::InputNormalizer.string(quote_by)
  end

  def quote_not_too_long
    return if quote.blank? || quote.length < 301

    errors.add :base, :quote_too_long
  end

  def calculated_owner_name
    self.class.calculated_owner_name(bike)
  end

  def image_processing?
    return false unless has_any_image? && updated_at > Time.current - 1.minute

    !photo_processed?
  end

  def photo_processed?
    photo_processed.attached?
  end

  def photo_url
    return unless photo_processed&.blob.present?

    BlobUrl.for(photo_processed.blob)
  end

  def image_alt
    "Photo of recovered bike"
  end

  def bike
    bike_id = stolen_record&.bike_id
    return unless bike_id.present?

    Bike.unscoped.find_by_id(bike_id)
  end

  def stolen_record
    stolen_record_id.present? ? StolenRecord.current_and_not.find_by_id(stolen_record_id) : nil
  end

  private

  def has_any_image?
    photo_processed? || photo.attached?
  end

  def enqueue_photo_processing
    return if skip_callback_job

    stolen_record&.update(updated_at: Time.current)
    if remote_photo_url.present?
      Images::ProcessRecoveryDisplayPhotoJob.perform_async(id, remote_photo_url)
      self.remote_photo_url = nil # clear to ensure it doesn't get re-enqueued
    elsif photo.attached? && !photo_processed.attached?
      # Otherwise, only enqueue if photo is attached and there isn't a photo_processed attached
      Images::ProcessRecoveryDisplayPhotoJob.perform_async(id)
    end
  end
end
