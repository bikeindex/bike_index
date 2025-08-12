# == Schema Information
#
# Table name: bulk_imports
#
#  id              :integer          not null, primary key
#  data            :jsonb
#  file            :text
#  file_cleaned    :boolean          default(FALSE)
#  import_errors   :json
#  is_ascend       :boolean          default(FALSE)
#  kind            :integer
#  no_notify       :boolean          default(FALSE)
#  progress        :integer          default("pending")
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  organization_id :integer
#  user_id         :integer
#
class BulkImport < ApplicationRecord
  PROGRESS_ENUM = {pending: 0, ongoing: 1, finished: 2}.freeze
  KIND_ENUM = {organization_import: 0, unorganized: 1, ascend: 2, impounded: 3, stolen: 4}.freeze
  VALID_FILE_EXTENSIONS = %(csv tsv).freeze
  FAILED_TIMEOUT = 20.minutes
  mount_uploader :file, BulkImportUploader

  belongs_to :organization
  belongs_to :user
  validates_presence_of :file, unless: :file_cleaned
  validate :ensure_valid_file_type
  has_many :ownerships
  has_many :bikes, through: :ownerships

  enum :progress, PROGRESS_ENUM
  enum :kind, KIND_ENUM

  scope :file_errors, -> { where("(import_errors -> 'file') IS NOT NULL") }
  scope :line_errors, -> { where("(import_errors -> 'line') IS NOT NULL") }
  scope :ascend_errors, -> { where("(import_errors -> 'ascend') IS NOT NULL") }
  # NOTE: the failed_timeout? method is slightly different - it has a shorter timeout for pending status
  scope :failed_timeout, -> { not_finished.where("created_at < ?", FAILED_TIMEOUT) }
  scope :import_errors, -> { file_errors.or(line_errors).or(failed_timeout) }
  scope :no_import_errors, -> { where("(import_errors -> 'line') IS NULL").where("(import_errors -> 'file') IS NULL") }
  scope :no_bikes, -> { where("(import_errors -> 'bikes') IS NOT NULL") }
  scope :with_bikes, -> { where.not("(import_errors -> 'bikes') IS NOT NULL") }
  scope :not_ascend, -> { where.not(kind: "ascend") }

  before_save :set_calculated_attributes
  after_commit :enqueue_job, on: :create

  def self.ascend_api_token
    ENV["ASCEND_API_TOKEN"]
  end

  def self.kinds
    KIND_ENUM.keys.map(&:to_s)
  end

  def self.progresses
    PROGRESS_ENUM.keys.map(&:to_s)
  end

  def self.kind_humanized(str)
    (str == "organization_import") ? "standard" : str&.tr("_", " ")
  end

  # NOTE: Headers were added in PR#1914 - 2021-3-11 - many bulk imports don't have them stored
  def headers
    data&.dig("headers")
  end

  def file_errors
    import_errors["file"]
  end

  def line_errors
    import_errors["line"]
  end

  def ascend_errors
    import_errors["ascend"]
  end

  def file_errors_with_lines
    return nil unless file_errors.present?
    [file_errors].flatten.zip(file_import_error_lines)
  end

  # Always return an array, because it's simpler to deal with - NOTE: different from above error methods which return nil
  def file_import_error_lines
    import_errors["file_lines"] || []
  end

  def import_errors?
    line_errors.present? || file_errors.present? || ascend_errors.present?
  end

  def failed_timeout?
    return false if finished? || created_at.blank?
    # If pending, fail if older than 5 minutes (it should have started processing by then!)
    # Doesn't match the scope exactly, which just uses FAILED_TIMEOUT
    timeout = pending? ? 5.minutes : FAILED_TIMEOUT
    created_at < Time.current - timeout
  end

  def blocking_error?
    ascend_errors.present? || file_errors.present? || failed_timeout?
  end

  def no_bikes?
    import_errors["bikes"] == "none_imported"
  end

  def ascend_unprocessable?
    ascend? && organization_id.blank?
  end

  def add_file_error(error_msg, line_error = "", skip_save: false)
    self.progress = "finished"
    return if file_errors.present? && file_errors.include?(error_msg)
    updated_file_error_data = {
      "file" => [file_errors, error_msg.to_s].compact.flatten,
      "file_lines" => [file_import_error_lines, line_error].flatten
    }
    return true if skip_save # Don't get stuck in a loop during creation
    # Using update_attribute here to avoid validation checks that sometimes block updating postgres json in rails
    update_attribute :import_errors, (import_errors || {}).merge(updated_file_error_data)
  end

  # If the bulk import failed on a line, start after that line, otherwise it's 1. See BulkImportJob
  def starting_line
    error_line = file_import_error_lines&.compact&.last
    error_line.present? ? error_line + 1 : 1
  end

  def send_email
    !no_notify
  end

  def no_duplicate=(val)
    self.data ||= {}
    self.data["no_duplicate"] = InputNormalizer.boolean(val)
  end

  def no_duplicate
    ascend? || InputNormalizer.boolean(data&.dig("no_duplicate"))
  end

  def creator
    organization&.auto_user || user
  end

  def kind_humanized
    self.class.kind_humanized(kind)
  end

  def filename
    "#{organization}_import_#{id}"
  end

  def file_filename
    file&.path&.split("/")&.last
  end

  def ascend_name
    file_filename.split("_-_").last.gsub(/\.\w{3,5}\z/, "")
  end

  def check_ascend_import_processable!
    self.import_errors = (import_errors || {}).except("ascend")
    if organization_id.blank?
      self.organization_id = organization_for_ascend_name&.id
      save if organization_id.present?
    end
    if organization_id.present? && invalid_extension?
      InvalidExtensionForAscendImportJob.perform_async(id)
    end
    return true if organization_id.present?
    add_ascend_import_error!
    UnknownOrganizationForAscendImportJob.perform_async(id)
    false # must return false, otherwise BulkImportJob enqueues processing
  end

  def organization_for_ascend_name
    org = Organization.where(ascend_name: ascend_name).first
    return org if org.present?
    regex_matcher = ascend_name.gsub(/-|_|\s/, "")
    Organization.ascend_pos.find { |org|
      org.ascend_name.present? && org.ascend_name.gsub(/-|_|\s/, "").match(/#{regex_matcher}/i)
    }
  end

  def stolen_record_attrs
    return {} unless stolen? && data&.dig("stolen_record").present?
    data["stolen_record"].merge(proof_of_ownership: true, receive_notifications: true)
  end

  def set_calculated_attributes
    self.kind ||= calculated_kind
    self.no_notify = true if kind == "stolen"
    # we're managing ascend errors separately because we need to lookup organization
    return true if ascend_unprocessable?
    unless creator.present?
      add_file_error("Needs to have a user or an organization with an auto user", skip_save: true)
    end
    if finished? && bikes.count == 0
      import_errors["bikes"] = "none_imported"
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
    @open_file ||= local_file? ? File.open(file.path, "r") : URI.parse(file.url).open
  rescue => e
    add_file_error(e.message)
    raise e
  end

  def enqueue_job
    BulkImportJob.perform_async(id) if persisted?
  end

  private

  def calculated_kind
    return "unorganized" if organization_id.blank?
    "organization_import" # Default
  end

  def invalid_extension?
    extension = (local_file? ? file.path : file.url)&.split(".")&.last
    extension.blank? || !VALID_FILE_EXTENSIONS.include?(extension)
  end

  def ensure_valid_file_type
    if invalid_extension?
      add_file_error("Invalid file extension, must be .csv or .tsv")
    end
  end

  def add_ascend_import_error!
    import_errors["ascend"] = ["Unable to find an Organization with ascend_name = #{ascend_name}"]
    save
  end
end
