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

  # Sized for display rather than for the source: `large` covers the show page hero at 2x, `small`
  # the search result cards. `small` stays jpeg because `thumb_path` feeds emails, and Outlook
  # desktop (still the Word rendering engine) won't render webp.
  VARIANTS = {
    small: {resize_to_fill: [300, 300], format: :jpeg},
    medium: {resize_to_fit: [1000, 750], format: :webp},
    large: {resize_to_fit: [2000, 1600], format: :webp}
  }.freeze

  # Direct uploads bypass the uploader, so nothing else holds an attached file to a format we
  # can serve, or to the size PublicImagesController caps. Wider than carrierwave's whitelist
  # by HEIC: iPhones shoot it by default and vips converts it to every variant, but carrierwave
  # can't take it, and that list also feeds the file picker's accept attribute.
  FILE_CONTENT_TYPES = (ApplicationUploader.extensions.map { Marcel::MimeType.for(name: "f.#{it}") } +
    %w[image/heic image/heif]).uniq.freeze

  mount_uploader :image, PublicImageUploader # Legacy, migrating to :file
  process_in_background :image, CarrierWaveProcessJob # Defer version generation so large uploads don't hit the 30s Rack::Timeout

  has_one_attached :file do |attachable|
    VARIANTS.each { |name, transformations| attachable.variant(name, **transformations) }
  end

  enum :kind, KIND_ENUM

  belongs_to :imageable, polymorphic: true

  # Only when a file is being assigned - otherwise every legacy carrierwave save pays a
  # query to load an attachment it doesn't have
  validate :file_permitted, if: -> { attachment_changes["file"].present? }
  attr_writer :image_cache
  attr_accessor :skip_update

  before_save :set_calculated_attributes
  after_commit :enqueue_after_commit_jobs

  default_scope { where(is_private: false).order(:listing_order) }
  scope :bike, -> { where(imageable_type: "Bike") }

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

  # Serves whichever backend this record was uploaded through. CarrierWave versions and
  # ActiveStorage variants share names, so callers pass the same size either way - the
  # ActiveStorage dimensions are just larger.
  def image_url(size = nil)
    return image.url(*size) unless file.attached?

    BlobUrl.for_variant(file, size&.to_sym&.presence_in(VARIANTS.keys))
  end

  # "processed" is only set once ProcessPublicImageJob has stripped the original and generated
  # every variant, so a job that died partway through gets picked up again
  def file_needs_processing?
    file.attached? && !file.blob.metadata["processed"]
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

    if file_needs_processing?
      # Stops the attachment's after_commit from enqueueing AnalyzeJob, whose metadata merge runs
      # off a stale read and would drop the job's flags. ProcessPublicImageJob analyzes instead.
      file.blob.analyzed = true
      Images::ProcessPublicImageJob.perform_async(id)
    end

    imageable&.update(updated_at: Time.current)
    return true unless bike?

    CallbackJobs::AfterBikeSaveJob.perform_async(imageable_id, false, true)
  end

  # CarrierWaveProcessJob generates versions by reading the stored original back
  # from remote storage, which only works with fog (production). With local file
  # storage (sandbox/dev) the worker can't see the web box's disk, so process
  # versions inline — otherwise the job silently skips them and thumbnails 404.
  def process_image_upload
    return true unless remote_storage?

    @process_image_upload
  end

  # Because the way we load the file is different if it's remote or local
  # This is hacky, but whatever. Only asked of carrierwave images - activestorage downloads
  # the same way whichever service it's on.
  def local_file?
    image&._storage&.to_s == "CarrierWave::Storage::File"
  end

  # Always a file on disk - URI.open returns a StringIO for remote files under 10kb,
  # which image processors can't read.
  # Returns nil when the file is missing (e.g. sandbox without synced uploads)
  def open_file
    return attached_tempfile if file.attached?

    if local_file?
      File.open(image.path, "r") if File.exist?(image.path)
    else
      Down.download(image.url)
    end
  end

  private

  def file_permitted
    blob = attachment_changes["file"].blob
    return if FILE_CONTENT_TYPES.include?(blob.content_type) &&
      blob.byte_size <= PublicImageUploader::MAX_FILE_SIZE

    errors.add(:file, :invalid)
  end

  # Not blob.open, which unlinks its tempfile when the block exits - the caller needs the file to
  # outlive this method. Plain download is one GET; the chunked form adds two HEADs on S3.
  def attached_tempfile
    tempfile = Tempfile.new(["public_image", File.extname(file.filename.to_s)], binmode: true)
    tempfile.write(file.blob.download)
    tempfile.tap(&:rewind)
  rescue ActiveStorage::FileNotFoundError
    tempfile&.close!
    nil
  end

  def remote_storage?
    PublicImageUploader.storage == CarrierWave::Storage::Fog
  end
end
