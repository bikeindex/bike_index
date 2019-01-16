class Export < ActiveRecord::Base
  VALID_PROGRESSES = %i[pending ongoing finished].freeze
  VALID_KINDS = %i[organization stolen manufacturer].freeze
  VALID_FILE_FORMATS = %i[csv xlsx].freeze
  DEFAULT_HEADERS = %w[link registered_at manufacturer model color serial is_stolen].freeze
  AVERY_HEADERS = %w[owner_name registration_address].freeze
  HIDDEN_HEADERS = %w[owner_name_or_email].freeze
  PERMITTED_HEADERS = (DEFAULT_HEADERS + %w[thumbnail registered_by registration_type owner_email owner_name] + HIDDEN_HEADERS).freeze

  mount_uploader :file, ExportUploader

  belongs_to :organization
  belongs_to :user # Creator of export
  enum progress: VALID_PROGRESSES
  enum kind: VALID_KINDS
  enum file_format: VALID_FILE_FORMATS

  before_validation :set_calculated_attributes

  attr_accessor :timezone, :avery_export # permit assignment

  def self.default_headers; DEFAULT_HEADERS end

  def self.default_options(kind)
    { "headers" => default_headers }.merge(default_kind_options[kind.to_s])
  end

  def self.additional_registration_fields
    { reg_address: "registration_address", reg_secondary_serial: "additional_registration_number", reg_phone: "phone" }
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

  def self.permitted_headers(organization = nil)
    return PERMITTED_HEADERS unless organization.present?
    additional_headers = organization == "include_paid" ? additional_registration_fields.keys : organization.additional_registration_fields
    PERMITTED_HEADERS + additional_headers.map { |f| additional_registration_fields[f.to_sym] }
  end

  def headers; options["headers"] end

  def option?(str)
    options[str.to_s].present?
  end

  def avery_export?
    option?("avery_export")
  end

  def avery_export=(val)
    if val
      self.options = options.merge(avery_export: true)
      self.attributes = { file_format: "xlsx", headers: AVERY_HEADERS }
    end
    true # Legacy concerns, so excited for TODO: Rails 5 update
  end

  def avery_export_url
    return nil unless avery_export? && finished?
    (ENV["AVERY_EXPORT_URL"] || "") + CGI.escape(file_url)
  end

  def start_at=(val)
    self.options = options.merge("start_at" => TimeParser.parse(val, timezone))
  end

  def end_at=(val)
    self.options = options.merge("end_at" => TimeParser.parse(val, timezone))
  end

  def headers=(val)
    self.options = options.merge("headers" => val)
  end

  def start_at
    option?("start_at") ? Time.parse(options["start_at"]) : nil
  end

  def end_at
    option?("end_at") ? Time.parse(options["end_at"]) : nil
  end

  def tmp_file
    @tmp_file ||= Tempfile.new(["#{kind == 'organization' ? organization.slug : kind}_#{id}", ".#{file_format}"])
  end

  def tmp_file_rows
    `wc -l "#{tmp_file.path}"`.strip.split(' ')[0].to_i - 1 # Because we don't count header
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
      option?("end_at") ? bikes.where(created_at: start_at..end_at) : bikes.where("bikes.created_at > ?", start_at)
    elsif option?("end_at") # If only end_at is present
      bikes.where("bikes.created_at < ?", end_at)
    else
      bikes
    end
  end

  def set_calculated_attributes
    self.options = validated_options(options)
    errors.add :organization_id, "required" if kind == "organization" && organization_id.blank?
    true # TODO: Rails 5 update
  end

  def validated_options(opts)
    opts = self.class.default_options(kind).merge(opts)
    # Permit setting any header - we'll block organizations setting those headers via show and also via controller
    # but if we want to manually create an export, we should be able to do so
    opts["headers"] = opts["headers"] & self.class.permitted_headers("include_paid")
    opts
  end
end
