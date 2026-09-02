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
#  index_public_images_on_created_at                       (created_at)
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

  # Every model with `has_many :public_images, as: :imageable`
  IMAGEABLE_TYPES = %w[Bike BikeVersion Blog ImpoundClaim MailSnippet Organization SocialPost].freeze

  # Sized for display rather than for the source: `large` covers the show page hero at 2x, `small`
  # the search result cards. `small` stays jpeg because `thumb_path` feeds emails, and Outlook
  # desktop (still the Word rendering engine) won't render webp. They downsize far enough to
  # need the sharpening mask image_processing 2.0 stopped applying by default.
  VARIANTS = {
    small: {resize_to_fill: [300, 300, {sharpen: true}], format: :jpeg},
    medium: {resize_to_fit: [1000, 750, {sharpen: true}], format: :webp},
    large: {resize_to_fit: [2000, 1600, {sharpen: true}], format: :webp}
  }.freeze

  # No browser renders TIFF and only Safari HEIC, so the job rewrites these as webp
  WEBP_SOURCE_TYPES = %w[image/heic image/heif image/tiff].freeze

  # Direct uploads bypass the uploader, so nothing else holds them to a format we can serve.
  # Wider than carrierwave's whitelist by HEIC - anything we convert has to be permitted
  FILE_CONTENT_TYPES = (ApplicationUploader.extensions.map { Marcel::MimeType.for(extension: it) } +
    WEBP_SOURCE_TYPES).uniq.freeze

  mount_uploader :image, PublicImageUploader # Legacy, migrating to :file
  process_in_background :image, CarrierWaveProcessJob # Defer version generation so large uploads don't hit the 30s Rack::Timeout

  has_one_attached :file do |attachable|
    VARIANTS.each { |name, transformations| attachable.variant(name, **transformations) }
  end

  enum :kind, KIND_ENUM

  belongs_to :imageable, polymorphic: true

  # Only when a file is assigned, so a legacy carrierwave save pays no attachment query
  validate :file_permitted, if: :file_attaching?
  attr_writer :image_cache
  attr_accessor :skip_update

  before_save :set_calculated_attributes
  before_save { @file_newly_attached = file_attaching? } # Nothing still says so at after_commit
  after_commit :enqueue_after_commit_jobs

  default_scope { where(is_private: false).order(:listing_order) }
  scope :bike, -> { where(imageable_type: "Bike") }
  # Complements, so the counts add up to the migration's progress
  scope :activestorage, -> { where.associated(:file_attachment) }
  scope :carrierwave, -> { where.missing(:file_attachment) }

  # Checked before the blob exists on direct upload, and again by the validation after
  def self.file_permitted?(content_type:, byte_size:)
    FILE_CONTENT_TYPES.include?(content_type) &&
      byte_size.to_i.between?(1, PublicImageUploader::MAX_FILE_SIZE)
  end

  def self.kinds = KIND_ENUM.keys.map(&:to_s)

  # Imageables label themselves differently, and some (ImpoundClaim, MailSnippet, SocialPost) not at all
  def imageable_name
    imageable.try(:display_name) || imageable.try(:name) || imageable.try(:title)
  end

  # A bike's name is its title_string, which stands alone - everything else names itself
  # after the source file, which doesn't
  def image_alt = (bike? ? [name] : [name, imageable_name]).filter_map(&:presence).join(" - ")

  def default_name
    return "#{imageable&.title_string} #{imageable&.frame_colors&.to_sentence}" if bike?

    # The carrierwave uploader is truthy with nothing stored, and its filename is nil then
    filename = activestorage? ? file.filename : image.filename
    File.basename(filename.to_s, ".*").titleize
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

  # A row holding both is activestorage: the attachment supersedes the carrierwave version
  def activestorage?
    file.attached?
  end

  def carrierwave? = !activestorage?

  # Not carrierwave's `image?`, which answers from that column - blank on an activestorage row
  def image_present? = image_url.present?

  # Both backends name their sizes the same, so callers pass one either way - the
  # activestorage dimensions are just larger
  def image_url(size = nil)
    return image.url(*size) unless activestorage?

    BlobUrl.for_variant(file, size&.to_sym&.presence_in(VARIANTS.keys))
  end

  # The blob stores it, but fog resolves it with a request per image - so carrierwave
  # rows are only worth asking from a cached fragment
  def image_size
    return file.blob.byte_size if activestorage?

    (image.size if image?)&.nonzero?
  end

  # "processed" lands only once the variants exist, so a job that died partway is picked up again
  def file_needs_processing?
    activestorage? && !file.blob.binx_data.to_h["processed"]
  end

  # Method to make create_revised.js easier to handle
  def bike_type
    return false unless %w[Bike BikeVersion].include?(imageable_type)

    imageable.present? ? imageable.cycle_type : "bike" # hidden bike handling
  end

  def enqueue_after_commit_jobs
    return if skip_update

    if external_image_url.present? && image.blank?
      return ImageJobs::ExternalUrlStoreJob.perform_async(id)
    end

    # Processing takes seconds, and every save in the meantime (reorder, is_private, kind) would
    # otherwise start a second run racing the first
    ImageJobs::ProcessPublicImageJob.perform_async(id) if @file_newly_attached && file_needs_processing?

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
    return attached_tempfile if activestorage?

    if local_file?
      File.open(image.path, "r") if File.exist?(image.path)
    else
      Down.download(image.url)
    end
  end

  private

  def file_attaching? = attachment_changes["file"].present?

  # A direct upload declares both, but attaching re-identifies content_type from the stored bytes
  # and byte_size is signed into the presigned PUT - so S3 rejects a body of any other length
  def file_permitted
    blob = attachment_changes["file"].blob
    return if self.class.file_permitted?(content_type: blob.content_type, byte_size: blob.byte_size)

    errors.add(:file, :invalid)
  end

  # Not blob.open: it unlinks on block exit, and the caller needs the file to outlive this.
  # Plain download is one GET; the chunked form adds two HEADs on S3
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
