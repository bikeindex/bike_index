class BulkImport < ActiveRecord::Base
  VALID_PROGRESSES = %i[pending ongoing finished].freeze
  mount_uploader :file, ImportExportUploader

  belongs_to :organization
  belongs_to :user
  validates_presence_of :file
  has_many :creation_states
  has_many :bikes, through: :creation_states

  enum progress: VALID_PROGRESSES

  before_save :validate_creator_present

  def file_import_errors
    import_errors["file"]
  end

  def line_import_errors
    import_errors["line"]
  end

  def import_errors?
    line_import_errors.present? || file_import_errors.present?
  end

  def add_file_error(error_msg)
    self.progress = "finished"
    # Using update_attribute here to avoid validation checks that sometimes block updating postgres json in rails
    update_attribute :import_errors, (import_errors || {}).merge("file" => [file_import_errors, error_msg].compact)
  end

  def send_email
    !no_notify
  end

  def creator
    organization && organization.auto_user || user
  end

  def filename
    "#{organization}_import_#{id}"
  end

  def validate_creator_present
    return true if creator.present?
    add_file_error("Needs to have a user or an organization with an auto user")
  end

  # Because the way we load the file is different if it's remote or local
  def local_file?
    file&._storage&.to_s == "CarrierWave::Storage::File"
  end

  # To enable stream processing, so that we aren't loading the whole file into memory all at once
  # also so we can separately deal with the header line
  def open_file
    @open_file ||= local_file? ? File.open(file.path, "r") : open(file.url)
  rescue => e
    pp e
  rescue OpenURI::HTTPError => e # This probably isn't the error that will happen, replace it with the one that is
    add_file_error(e.message)
  end
end
