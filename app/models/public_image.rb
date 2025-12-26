# == Schema Information
#
# Table name: public_images
# Database name: primary
#
#  id                 :integer          not null, primary key
#  external_image_url :text
#  image              :string(255)
#  imageable_type     :string(255)
#  is_private         :boolean          default(FALSE), not null
#  kind               :integer          default("photo_uncategorized")
#  listing_order      :integer          default(0)
#  name               :string(255)
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  imageable_id       :integer
#
# Indexes
#
#  index_public_images_on_imageable_id_and_imageable_type  (imageable_id,imageable_type)
#
class PublicImage < ApplicationRecord
  KIND_ENUM = {
    photo_uncategorized: 0, # If editing these images, also update _public_image template
    photo_stock: 3,
    photo_of_user_with_bike: 4,
    photo_of_serial: 5,
    photo_of_receipt: 6
  }.freeze

  mount_uploader :image, ImageUploader # Not processed in background, because they are uploaded directly

  enum :kind, KIND_ENUM

  belongs_to :imageable, polymorphic: true

  before_save :set_calculated_attributes
  after_commit :enqueue_after_commit_jobs

  default_scope { where(is_private: false).order(:listing_order) }
  scope :bike, -> { where(imageable_type: "Bike") }

  attr_writer :image_cache
  attr_accessor :skip_update

  def default_name
    if bike?
      self.name = "#{imageable&.title_string} #{imageable&.frame_colors&.to_sentence}"
    elsif image
      self.name ||= File.basename(image.filename, ".*").titleize
    end
  end

  def set_calculated_attributes
    self.kind ||= "photo_uncategorized"
    self.name = (name || default_name).truncate(100)
    return true if listing_order && listing_order > 0

    self.listing_order = imageable&.public_images&.length || 0
  end

  def bike?
    imageable_type == "Bike"
  end

  # Method to make create_revised.js easier to handle
  def bike_type
    return false unless %w[Bike BikeVersion].include?(imageable_type)

    imageable.present? ? imageable.cycle_type : "bike" # hidden bike handling
  end

  def enqueue_after_commit_jobs
    return if skip_update

    if external_image_url.present? && image.blank?
      return Images::ExternalUrlStoreJob.perform_async(id)
    end

    imageable&.update(updated_at: Time.current)
    return true unless bike?

    ::CallbackJob::AfterBikeSaveJob.perform_async(imageable_id, false, true)
  end

  # Because the way we load the file is different if it's remote or local
  # This is hacky, but whatever
  def local_file?
    image&._storage&.to_s == "CarrierWave::Storage::File"
  end

  # To enable stream processing for both local and remote files
  def open_file
    local_file? ? File.open(image.path, "r") : URI.parse(image.url).open
  end
end
