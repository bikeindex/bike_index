class ModelAudit < ApplicationRecord
  enum certification_status: ModelAttestation::CERTIFICATION_KIND_ENUM
  enum propulsion_type: PropulsionType::SLUGS
  enum cycle_type: CycleType::SLUGS

  belongs_to :manufacturer

  has_many :bikes
  has_many :model_attestations
  has_many :organization_model_audits

  validates_uniqueness_of :frame_model, scope: %i[manufacturer_id manufacturer_other], allow_nil: false, case_sensitive: false


  before_validation :set_calculated_attributes

  def self.certification_status_humanized(str)
    return nil if str.blank?
    str.to_s.gsub("_org", " organization").tr("_", " ")
  end

  def self.valid_kinds
    (certification_statuses.keys - ["certification_proof_url"])
  end

  def self.matching_bikes_for(bike = nil, manufacturer_id: nil, mnfg_name: nil, frame_model: nil)
    manufacturer_id ||= bike&.manufacturer_id
    bikes = Bike.unscoped.where(manufacturer_id: manufacturer_id)
    if manufacturer_id == Manufacturer.other.id
      mnfg_name ||= bike&.mnfg_name
      bikes = bikes.where("mnfg_name ILIKE ?", mnfg_name)
    end
    frame_model ||= bike&.frame_model
    bikes = bikes.where("frame_model ILIKE ?", frame_model)
    bikes.reorder(id: :desc)
  end

  def set_calculated_attributes
    self.manufacturer_other = nil if manufacturer_id != Manufacturer.other.id
    self.mnfg_name = Manufacturer.calculated_mnfg_name(manufacturer, manufacturer_other)
    self.certification_status = calculated_certification_status
  end

  # TODO: include display for model missing
  def frame_model_display
    frame_model
  end

  private

  def calculated_certification_status
    (self.class.valid_kinds & model_attestations.current.distinct.pluck(:kind)).first
  end
end
