class Export < ActiveRecord::Base
  VALID_PROGRESSES = %i[pending ongoing finished].freeze
  VALID_KINDS = %i[organization stolen manufacturer].freeze
  DEFAULT_HEADERS = %w[registered_at].freeze
  PERMITTED_HEADERS = (DEFAULT_HEADERS + %w[registered_by registration_type]).freeze
  mount_uploader :file, ImportExportUploader

  belongs_to :organization
  enum progress: VALID_PROGRESSES
  enum kind: VALID_KINDS

  before_validation :set_calculated_attributes

  def self.default_headers; DEFAULT_HEADERS end

  def self.default_options(kind)
    { "format" => "csv", "headers" => default_headers }.merge(default_kind_options[kind.to_s])
  end

  def self.default_kind_options
    {
      stolen: {
        with_blacklist: false,
        only_serials_and_police_reports: false
      },
      organization: {
        partial_registrations: false,
        start_at: nil,
        end_at: nil
      },
      manufacturer: {
        frame_only: false
      }
    }.as_json.freeze
  end

  def headers; options["headers"] end

  def option?(str)
    options[str.to_s].present?
  end

  def start_at
    option?("start_at") ? Time.parse(options["start_at"]) : nil
  end

  def end_at
    option?("end_at") ? Time.parse(options["end_at"]) : nil
  end

  def description
    if kind == "stolen"
      txt = "Stolen"
      txt += " with serials & police reports" if option?("only_serials_and_police_reports")
      txt += " (without blacklisted bikes)" unless option?("with_blacklist")
      txt
    elsif kind == "manufacturer"
      "Manufacturer"
    else
      "Organization export"
    end
  end

  def bikes_scoped
    raise "#{kind} scoping not set up" unless kind == "organization"
    bikes = organization.bikes
    if option?("start_at")
      bikes = option?("end_at") ? bikes.where(created_at: start_at..end_at) : bikes.where("created_at > ?", start_at)
    end
    bikes
  end

  def set_calculated_attributes
    self.options = validated_options(options)
    errors.add :organization_id, "required" if kind == "organization" && organization_id.blank?
    true # TODO: Rails 5 update
  end

  def validated_options(opts)
    opts = self.class.default_options(kind).merge(opts)
    opts["headers"] = opts["headers"] & PERMITTED_HEADERS
    opts
  end
end
