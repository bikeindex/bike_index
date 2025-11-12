# == Schema Information
#
# Table name: exports
# Database name: primary
#
#  id              :integer          not null, primary key
#  file            :text
#  file_format     :integer          default("csv")
#  kind            :integer          default("organization")
#  options         :jsonb
#  progress        :integer          default("pending")
#  rows            :integer
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  organization_id :integer
#  user_id         :integer
#
# Indexes
#
#  index_exports_on_organization_id  (organization_id)
#  index_exports_on_user_id          (user_id)
#
class Export < ApplicationRecord
  PROGRESS_ENUM = {
    pending: 0,
    ongoing: 1,
    finished: 2,
    errored: 3
  }.freeze
  VALID_KINDS = {
    organization: 0,
    stolen: 1,
    manufacturer: 2
  }.freeze
  VALID_FILE_FORMATS = %i[csv xlsx].freeze
  DEFAULT_HEADERS = %w[
    color
    is_stolen
    link
    manufacturer
    model
    registered_at
    serial
  ].freeze
  EXTRA_HEADERS = %w[
    extra_registration_number
    motorized
    owner_email
    owner_name
    registered_by
    status
    thumbnail
    vehicle_type
  ].freeze
  AVERY_HEADERS = %w[address owner_name].freeze
  PERMITTED_HEADERS = (DEFAULT_HEADERS + EXTRA_HEADERS).sort.freeze

  mount_uploader :file, ExportUploader

  belongs_to :organization
  belongs_to :user # Creator of export
  enum :progress, PROGRESS_ENUM
  enum :kind, VALID_KINDS
  enum :file_format, VALID_FILE_FORMATS

  before_validation :set_calculated_attributes

  scope :avery, -> { where("(options -> 'avery_export') IS NOT NULL") }

  attr_accessor :timezone # permit assignment
  attr_reader :avery_export

  def self.default_headers
    DEFAULT_HEADERS
  end

  def self.default_options(kind)
    {"headers" => default_headers}.merge(default_kind_options[kind.to_s])
  end

  def self.default_kind_options
    {
      stolen: {
        with_blocklist: false,
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

  def self.permitted_headers(organization_or_overide = nil)
    return PERMITTED_HEADERS unless organization_or_overide.present?

    if organization_or_overide == "include_paid" # passing include_paid overrides
      additional_headers = OrganizationFeature::REG_FIELDS
    elsif organization_or_overide.is_a?(Organization)
      additional_headers = organization_or_overide.additional_registration_fields
      additional_headers += ["partial_registration"] if organization_or_overide.enabled?("show_partial_registrations")
      additional_headers += ["is_impounded"] if organization_or_overide.enabled?("impound_bikes")
    end
    additional_headers = additional_headers.map { |h| h.gsub("reg_", "") } # skip the reg_ prefix, we don't want to display it
    # We always give the option to export extra_registration_number, don't double up if org can add too
    (PERMITTED_HEADERS + additional_headers).uniq
  end

  def self.with_bike_sticker_code(bike_sticker_code)
    where("options->'bike_codes_assigned' @> ?", [bike_sticker_code].to_json)
  end

  def finished_processing?
    %w[finished errored].include?(progress)
  end

  def headers
    options["headers"]
  end

  def avery_export?
    option?("avery_export")
  end

  def bike_code_start
    options["bike_code_start"]
  end

  def assign_bike_codes
    bike_code_start.present? || options["assign_bike_codes"].present?
  end

  def assign_bike_codes?
    assign_bike_codes
  end

  def bike_codes_removed?
    option?("bike_codes_removed")
  end

  def custom_bike_ids
    options["custom_bike_ids"]
  end

  def only_custom_bike_ids
    options["only_custom_bike_ids"]
  end

  def only_custom_bike_ids=(val)
    options["only_custom_bike_ids"] = InputNormalizer.boolean(val)
  end

  def partial_registrations
    options["partial_registrations"].blank? ? false : options["partial_registrations"]
  end

  # NOTE: Only does the first 100 bikes, in case there is a huge export
  def exported_bike_ids
    options["exported_bike_ids"]
  end

  # 'options' is a weird place to put the assigned bike_stickers - but whatever, it's there, just using it
  def bike_stickers_assigned
    options["bike_codes_assigned"] || []
  end

  def remove_bike_stickers_and_record!(passed_user = nil)
    return true unless assign_bike_codes? && !bike_codes_removed?

    remove_bike_stickers(passed_user)
    update_attribute :options, options.merge(bike_codes_removed: true)
  end

  def remove_bike_stickers(passed_user = nil)
    (bike_stickers_assigned || []).each do |code|
      BikeSticker.lookup(code, organization_id: organization_id)
        &.claim(user: passed_user, bike_string: nil, organization: organization, creator_kind: "creator_export")
    end
  end

  def option?(str)
    options[str.to_s].present?
  end

  def assign_exported_bike_ids
    # Store the first 100 bike ids that were exported, for diagnostic purposes
    self.options = options.merge("exported_bike_ids" => bikes_scoped.limit(100).pluck(:id))
  end

  def assign_bike_codes=(val)
    if val
      self.options = options.merge(assign_bike_codes: true)
    end
  end

  def avery_export=(val)
    if val
      self.options = options.merge(avery_export: true)
      self.attributes = {file_format: "xlsx", headers: AVERY_HEADERS}
    end
  end

  def bike_code_start=(val)
    return unless val.present?

    self.options = options.merge(bike_code_start: BikeSticker.normalize_code(val, leading_zeros: true))
  end

  def custom_bike_ids=(val)
    custom_ids = if val.is_a?(Array)
      val
    else
      # Organized Bikes controller uses _ as delimiter to shorten encoded URL length
      val.match?(/\A\w*\z/) ? val.split("_") : val.split(/\s+|,/)
    end.map { |cid| bike_id_from_url(cid) }.compact.uniq
    custom_ids = nil if custom_ids.none?
    self.options = options.merge(custom_bike_ids: custom_ids)
  end

  def written_headers
    # Initially didn't record "written headers", so provide a fallback
    # ... but it's nice to actually have the final output headers, since we do some modifications
    option?("written_headers") ? options["written_headers"] : headers
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
    @tmp_file ||= Tempfile.new(["#{(kind == "organization") ? organization.slug : kind}_#{id}", ".#{file_format}"])
  end

  def tmp_file_rows
    `wc -l "#{tmp_file.path}"`.strip.split(" ")[0].to_i - 1 # Because we don't count header
  end

  def description
    if kind == "stolen"
      txt = "Stolen"
      txt += " with serials & police reports" if option?("only_serials_and_police_reports")
      txt += " (without blocklisted bikes)" unless option?("with_blocklist")
      txt
    elsif kind == "manufacturer"
      "Manufacturer"
    else
      "Organization export"
    end
  end

  def bikes_scoped
    raise "#{kind} scoping not set up" unless kind == "organization"
    return Bike.none if partial_registrations == "only"
    return organization.bikes.where(id: custom_bike_ids) if only_custom_bike_ids
    return bikes_within_time(organization.bikes) unless custom_bike_ids.present?

    bikes_within_time(organization.bikes).or(organization.bikes.where(id: custom_bike_ids))
  end

  def incompletes_scoped
    return BParam.none unless partial_registrations.present?

    incompletes = organization.incomplete_b_params
    return incompletes unless option?("start_at") || option?("end_at")

    if option?("start_at")
      option?("end_at") ? incompletes.where(created_at: start_at..end_at) : incompletes.where("b_params.created_at > ?", start_at)
    elsif option?("end_at") # If only end_at is present
      incompletes.where("b_params.created_at < ?", end_at)
    end
  end

  def set_calculated_attributes
    self.options = validated_options(options)
    errors.add :organization_id, :required if kind == "organization" && organization_id.blank?
    self.progress = calculated_progress
  end

  # Generally, use calculated_progress rather than progress directly for display
  def calculated_progress
    return progress unless pending? || ongoing?

    ((created_at || Time.current) < Time.current - 10.minutes) ? "errored" : progress
  end

  def validated_options(opts)
    opts = self.class.default_options(kind).merge(opts)
    # Permit setting any header - we'll block organizations setting those headers via show and also via controller
    # but if we want to manually create an export, we should be able to do so
    opts["headers"] = opts["headers"] & self.class.permitted_headers("include_paid")
    opts
  end

  private

  def bikes_within_time(bikes)
    return bikes unless option?("start_at") || option?("end_at")

    if option?("start_at")
      option?("end_at") ? bikes.where(created_at: start_at..end_at) : bikes.where("bikes.created_at > ?", start_at)
    elsif option?("end_at") # If only end_at is present
      bikes.where("bikes.created_at < ?", end_at)
    end
  end

  def bike_id_from_url(bike_url)
    return nil unless bike_url.present?
    return bike_url if bike_url.is_a?(Integer) # integers passed directly in organized bikes_controller

    id_str = bike_url.strip
    if id_str.match?(/\A\d+\z/)
      id_str.to_i
    else
      bike_id = id_str[/bikes\/\d+/i]
      bike_id.present? ? bike_id.gsub(/bikes\//i, "").to_i : nil
    end
  end
end
