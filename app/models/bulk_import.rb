class BulkImport < ActiveRecord::Base
  VALID_PROGRESS = %i[pending ongoing finished].freeze

  belongs_to :organization
  belongs_to :user
  validates_presence_of :user_id, :file_url
  validates_uniqueness_of :file_url
  has_many :bikes

  enum progress: VALID_PROGRESS

  def file_import_errors
    import_errors["file"]
  end

  def line_import_errors
    import_errors["line"]
  end

  def add_file_error(error_msg)
    self.progress = "finished"
    update_attribute :import_errors, (import_errors || {}).merge("file" => [file_import_errors, error_msg].compact)
  end

  def send_email
    !no_notify
  end

  def file
    require "open-uri"
    open(file_url)
  rescue OpenURI::HTTPError => e
    add_file_error(e.message)
  end
end
