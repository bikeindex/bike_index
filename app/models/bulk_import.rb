class BulkImport < ActiveRecord::Base
  VALID_PROGRESSES = %i[pending ongoing finished].freeze
  mount_uploader :file, BulkImportUploader

  belongs_to :organization
  belongs_to :user
  validates_presence_of :file
  has_many :creation_states
  has_many :bikes, through: :creation_states

  enum progress: VALID_PROGRESSES

  scope :file_errors, -> { where("(import_errors -> 'file') is not null") }
  scope :line_errors, -> { where("(import_errors -> 'line') is not null") }
  scope :no_bikes, -> { where("(import_errors -> 'bikes') is not null") }
  scope :with_bikes, -> { where.not("(import_errors -> 'bikes') is not null") }
  scope :ascend, -> { where(is_ascend: true) }

  before_save :set_calculated_attributes

  def self.ascend_api_token; ENV["ASCEND_API_TOKEN"] end

  def file_import_errors; import_errors["file"] || import_errors["ascend"] end

  def line_import_errors; import_errors["line"] end

  def file_import_errors_with_lines
    return nil unless file_import_errors.present?
    ([file_import_errors].flatten).zip(file_import_error_lines)
  end

  # Always return an array, because it's simpler to deal with - NOTE: different from above error methods which return nil
  def file_import_error_lines; import_errors["file_lines"] || [] end

  def import_errors?; line_import_errors.present? || file_import_errors.present? end

  def blocking_error?; file_import_errors.present? || pending? && created_at && created_at < Time.now - 5.minutes end

  def no_bikes?; import_errors["bikes"] == "none_imported" end

  def ascend?; is_ascend end

  def ascend_unprocessable?; ascend? && organization_id.blank? end

  def add_file_error(error_msg, line_error = "", skip_save: false)
    self.progress = "finished"
    updated_file_error_data = {
      "file" => [file_import_errors, error_msg.to_s].compact.flatten,
      "file_lines" => [file_import_error_lines, line_error].flatten,
    }
    return true if skip_save # Don't get stuck in a loop during creation
    # Using update_attribute here to avoid validation checks that sometimes block updating postgres json in rails
    update_attribute :import_errors, (import_errors || {}).merge(updated_file_error_data)
  end

  # If the bulk import failed on a line, start after that line, otherwise it's 1. See BulkImportWorker
  def starting_line
    error_line = file_import_error_lines&.compact&.last
    error_line.present? ? error_line + 1 : 1
  end

  def send_email
    !no_notify
  end

  def creator
    organization&.auto_user || user
  end

  def filename
    "#{organization}_import_#{id}"
  end

  def file_filename
    file&.path&.split("/")&.last
  end

  def ascend_name
    file_filename.split("_-_").last.gsub(".csv", "")
  end

  def check_ascend_import_processable!
    self.import_errors = (import_errors || {}).except("ascend")
    self.organization_id ||= organization_for_ascend_name&.id
    return true if organization_id.present?
    self.import_errors["ascend"] = "Unable to find an Organization with ascend_name = #{ascend_name}"
    save
    UnknownOrganizationForAscendImportWorker.perform_async(id)
    false
  end

  def organization_for_ascend_name
    org = Organization.where(ascend_name: ascend_name).first
    return org if org.present?
    regex_matcher = ascend_name.gsub(/-|_|\s/, "")
    Organization.where.not(ascend_name: nil).select do |org|
      next false unless org.ascend_imports?
      org.ascend_name.present? && org.ascend_name.gsub(/-|_|\s/, "").match(/#{regex_matcher}/i)
    end.first
  end

  def set_calculated_attributes
    self.is_ascend = false unless is_ascend # Ensure no null
    # we're managing ascend errors separately because we need to lookup organization
    return true if ascend_unprocessable?
    unless creator.present?
      add_file_error("Needs to have a user or an organization with an auto user", skip_save: true)
    end
    if finished? && bikes.count == 0
      self.import_errors["bikes"] = "none_imported"
    end
    true
  end

  # Because the way we load the file is different if it's remote or local
  # This is hacky, but whatever
  def local_file?
    file&._storage&.to_s == "CarrierWave::Storage::File"
  end

  # To enable stream processing, so that we aren't loading the whole file into memory all at once
  # also so we can separately deal with the header line
  def open_file
    @open_file ||= local_file? ? File.open(file.path, "r") : open(file.url)
  rescue => e
    add_file_error(e.message)
    raise e
  end
end
