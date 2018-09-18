class Export < ActiveRecord::Base
  VALID_PROGRESSES = %i[pending ongoing finished].freeze
  VALID_KINDS = %i[organization stolen manufacturer].freeze
  mount_uploader :file, ImportExportUploader

  belongs_to :organization
  enum progress: VALID_PROGRESSES
  enum kind: VALID_KINDS

  before_validation :set_calculated_attributes

  def self.default_options
    {
      stolen: {
        with_blacklist: false,
        only_serials_and_police_reports: false,
      },
      organization: {
        start_at: nil,
        end_at: nil
      },
      manufacturer: {
        frame_only: false
      }
    }.as_json.freeze
  end

  # t.integer :rows, default: 0
  # t.json :export_errors, default: {}

  def has_option?(str)
    options[str.to_s].present?
  end

  def description
    if kind == "stolen"
      txt = "Stolen"
      txt += " with serials & police reports" if has_option?("only_serials_and_police_reports")
      txt += " (without blacklisted bikes)" unless has_option?("with_blacklist")
      txt
    elsif kind == "manufacturer"
      "Manufacturer"
    else
      "Organization export"
    end
  end

  def set_calculated_attributes
    self.options = self.class.default_options[kind].merge(options)
    errors.add :organization_id, "Organization required" if kind == "organization" && organization_id.blank?
    true # TODO: Rails 5 update
  end
end
