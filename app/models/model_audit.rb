# == Schema Information
#
# Table name: model_audits
#
#  id                   :bigint           not null, primary key
#  bikes_count          :integer
#  certification_status :integer
#  cycle_type           :integer
#  frame_model          :string
#  manufacturer_other   :string
#  mnfg_name            :string
#  propulsion_type      :integer
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  manufacturer_id      :bigint
#
# Indexes
#
#  index_model_audits_on_manufacturer_id  (manufacturer_id)
#
class ModelAudit < ApplicationRecord
  UNKNOWN_STRINGS = %w[na idk no none nomodel tbd unknown unkown].freeze
  ADDITIONAL_CYCLE_TYPES = %w[bicycle dirtbike trike three-wheeler 3-wheeler].freeze
  VARIETIES_MATCHERS = %w[
    men.?s male female lady.?s? ladies women.?s
    sm(all)? me?d(ium)? l(ar)?ge? xx?s xx?l regular
    bmx city commuter cruiser hybrid mtb mountain road utility traditional
    aluminum electric fat(.?tire)? foldable folding frame full.suspension
    long.?tail mid.?tail high.?step mid.?step step.?through step.?thru step.?in
  ].freeze

  enum :certification_status, ModelAttestation::CERTIFICATION_KIND_ENUM
  enum :propulsion_type, PropulsionType::SLUGS
  enum :cycle_type, CycleType::SLUGS

  belongs_to :manufacturer

  has_many :bikes
  has_many :model_attestations
  has_many :organization_model_audits, dependent: :destroy

  validates_uniqueness_of :frame_model, scope: %i[manufacturer_id manufacturer_other], allow_nil: false, case_sensitive: false

  before_validation :set_calculated_attributes

  scope :unknown_model, -> { where(frame_model: nil) }

  class << self
    def valid_kinds
      (certification_statuses.keys - ["certification_proof_url"])
    end

    def manufacturer_id_corrected(manufacturer_id, mnfg_name)
      return manufacturer_id if manufacturer_id != Manufacturer.other.id
      Manufacturer.friendly_find_id(mnfg_name) || manufacturer_id
    end

    def matching_manufacturer(manufacturer_id, mnfg_name)
      model_audits = where("mnfg_name ILIKE ?", mnfg_name)
      manufacturer_id = manufacturer_id_corrected(manufacturer_id, mnfg_name)
      return model_audits if manufacturer_id == Manufacturer.other.id
      model_audits.or(where(manufacturer_id: manufacturer_id))
    end

    def find_for(bike = nil, manufacturer_id: nil, mnfg_name: nil, frame_model: nil)
      manufacturer_id ||= bike&.manufacturer_id
      mnfg_name ||= bike&.mnfg_name
      frame_model ||= bike&.frame_model
      matching_audits = matching_manufacturer(manufacturer_id, mnfg_name)
        .matching_frame_model(frame_model, manufacturer_id: manufacturer_id).reorder(:id)
      return matching_audits.first if matching_audits.count < 2
      not_other = matching_audits.where.not(manufacturer_id: Manufacturer.other.id)
      not_other.present? ? not_other.first : matching_audits.first
    end

    def unknown_model?(frame_model, manufacturer_id:)
      return true if frame_model.blank? ||
        UNKNOWN_STRINGS.include?(normalize_model_string(frame_model)) ||
        model_bare_vehicle_type?(frame_model)
      # Ignore manufacturer other
      return false if [Manufacturer.other.id, nil].include?(manufacturer_id)

      Manufacturer.friendly_find_id(frame_model) == manufacturer_id
    end

    def audit?(bike)
      return true if bike.motorized? || bike.manufacturer&.motorized_only?
      if bike.manufacturer&.other?
        manufacturer_id = manufacturer_id_corrected(bike.manufacturer_id, bike.mnfg_name)
        if manufacturer_id != Manufacturer.other.id
          return true if Manufacturer.find_by_id(manufacturer_id)&.motorized_only?
        end
      end
      return false if unknown_model?(bike.frame_model, manufacturer_id: bike.manufacturer_id)
      # Also enqueue if any matching bikes have a model_audit
      ModelAudit.matching_bikes_for(bike).where.not(model_audit_id: nil).limit(1).any?
    end

    def matching_bikes_for(bike = nil, manufacturer_id: nil, mnfg_name: nil, frame_model: nil)
      manufacturer_id ||= bike&.manufacturer_id
      mnfg_name ||= bike&.mnfg_name || Manufacturer.find_by_id(manufacturer_id)&.short_name
      # Always match by mnfg_name, to fix things if it previously was manufacturer_other
      bikes = Bike.unscoped.where("mnfg_name ILIKE ?", mnfg_name)
      if manufacturer_id != Manufacturer.other.id
        bikes = bikes.or(Bike.unscoped.where(manufacturer_id: manufacturer_id))
      end
      bikes = matching_bikes_for_frame_model(bikes, manufacturer_id: manufacturer_id, frame_model: frame_model || bike&.frame_model)
      # Include bike if it was passed
      bikes = bikes.or(Bike.unscoped.where(id: bike.id)) if bike&.id.present?
      bikes.reorder(id: :desc)
    end

    def counted_matching_bikes(bikes)
      bikes.where(example: false, deleted_at: nil, likely_spam: false)
    end

    def counted_matching_bikes_count(bikes)
      # As of now, user_hidden isn't normally visible in orgs. Not sure what to do about that?
      counted_matching_bikes(bikes).count
    end

    def matching_frame_model(frame_model, manufacturer_id:)
      if unknown_model?(frame_model, manufacturer_id: manufacturer_id)
        where(frame_model: nil)
      else
        where("frame_model ILIKE ?", frame_model)
      end
    end

    private

    def matching_bikes_for_frame_model(bikes, manufacturer_id:, frame_model:)
      if unknown_model?(frame_model, manufacturer_id: manufacturer_id)
        bikes = bikes.motorized unless Manufacturer.find_by_id(manufacturer_id)&.motorized_only
        bikes.where(frame_model: nil).or(bikes.where("frame_model ILIKE ANY (array[?])", UNKNOWN_STRINGS))
      else
        bikes.where("frame_model ILIKE ?", frame_model)
      end
    end

    def normalize_model_string(frame_model)
      frame_model.downcase.gsub(/\W|_|\s/, "") # remove everything but numbers and letters
    end

    def model_bare_vehicle_type?(frame_model)
      match_string = model_without_varieties(frame_model)
      match_string.blank? || vehicle_type_strings.include?(match_string)
    end

    def model_without_varieties(frame_model)
      match_string = frame_model.downcase.strip.gsub(/\W|_/, " ")
      # Replace all varities with a space
      (VARIETIES_MATCHERS + Color::ALL_NAMES.map { |c| c.split(/\W/).first.downcase })
        .each { |v| match_string.gsub!(/(\A| )#{v}( |\z)/, " ") }
      # remove cargo (which is often compounded with other types) and convert spaces to dashes
      match_string.gsub("cargo", " ").strip.gsub(/ +/, "-")
        .gsub(/\A(electric|e)-?/, "") # remove leading e/electric ("electric" not leading removed by variety)
    end

    def vehicle_type_strings
      CycleType::SLUGS.keys.map { |s| s.to_s.split(/(\A|-)e-/).last }
        .reject { |s| s.match?("cargo") } + ADDITIONAL_CYCLE_TYPES
    end
  end

  # WARNING! This is a calculated query. You should probably use the association
  def matching_bikes
    self.class.matching_bikes_for(nil, manufacturer_id: manufacturer_id, mnfg_name: mnfg_name, frame_model: frame_model)
  end

  # WARNING! This is a calculated query.
  def counted_matching_bikes_count
    self.class.counted_matching_bikes_count(matching_bikes)
  end

  def matching_bike?(bike)
    same_frame_model = if self.class.unknown_model?(bike.frame_model, manufacturer_id: bike.manufacturer_id)
      unknown_model?
    else
      frame_model&.downcase == bike.frame_model&.downcase
    end
    return false unless same_frame_model
    mnfg_name.downcase == bike.mnfg_name.downcase
  end

  def delete_if_no_bikes?
    model_attestations.limit(1).blank?
  end

  def unknown_model?
    frame_model.blank?
  end

  def should_be_unknown_model?
    frame_model.present? &&
      self.class.unknown_model?(frame_model, manufacturer_id: manufacturer_id)
  end

  def certification_status_humanized
    ModelAttestation.kind_humanized(certification_status)
  end

  def cycle_type_name
    CycleType.new(cycle_type)&.name
  end

  def propulsion_type_name
    PropulsionType.new(propulsion_type).name
  end

  def set_calculated_attributes
    self.manufacturer_other = nil if manufacturer_id != Manufacturer.other.id
    self.mnfg_name = Manufacturer.calculated_mnfg_name(manufacturer, manufacturer_other)
    self.certification_status = calculated_certification_status
  end

  private

  def calculated_certification_status
    (self.class.valid_kinds & model_attestations.current.certification_updating.distinct.pluck(:kind)).first
  end
end
