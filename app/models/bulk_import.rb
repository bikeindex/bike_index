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

  def open_file
    file.read # This isn't stream processing, it would be nice if it was
  rescue OpenURI::HTTPError => e # This probably isn't the error that will happen, replace it with the one that is
    add_file_error(e.message)
  end
end
