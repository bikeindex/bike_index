# == Schema Information
#
# Table name: recovery_displays
# Database name: primary
#
#  id               :integer          not null, primary key
#  image            :string(255)
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

  mount_uploader :image, CircularImageUploader
  process_in_background :image, CarrierWaveProcessJob

  # ActiveStorage for new image uploads (non-circular)
  has_one_attached :photo
  has_one_attached :photo_processed

  after_commit :enqueue_photo_processing, on: [:create, :update]

  attr_writer :image_cache
  attr_accessor :date_input, :remote_photo_url

  validates_presence_of :quote, :recovered_at
  validate :quote_not_too_long

  before_validation :set_calculated_attributes
  before_save :attach_remote_image
  after_commit :update_associations

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
    self.link = InputNormalizer.string(link)
    self.location_string = InputNormalizer.string(location_string)
    self.quote = InputNormalizer.string(quote)
    self.quote_by = InputNormalizer.string(quote_by)
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

    !image_exists?
  end

  def image_exists?
    if photo_processed.attached?
      true
    elsif photo.attached?
      true
    elsif image.present?
      image.file.exists?
    else
      false
    end
  end

  def has_any_image?
    photo_processed.attached? || photo.attached? || image.present?
  end

  # Alias for CarrierWave compatibility
  def image?
    has_any_image?
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

  def update_associations
    stolen_record&.update(updated_at: Time.current)
  end

  def enqueue_photo_processing
    return unless photo.attached? && !photo_processed.attached?

    RecoveryDisplay::AfterPhotoAttachJob.perform_async(id)
  end

  def attach_remote_image
    return if remote_photo_url.blank?
    return if photo.attached? # Don't override existing photo

    begin
      downloaded_image = URI.parse(remote_photo_url).open
      filename = File.basename(URI.parse(remote_photo_url).path)
      photo.attach(io: downloaded_image, filename:)
      self.remote_photo_url = nil # Clear after attaching
    rescue => e
      Rails.logger.error("Failed to attach remote image for RecoveryDisplay: #{e.message}")
      errors.add(:remote_photo_url, "could not be downloaded")
      false
    end
  end
end
