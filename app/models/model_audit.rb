class ModelAudit < ApplicationRecord
  enum certification_status: ModelAttestation::CERTIFICATION_KIND_ENUM
  enum propulsion_type: PropulsionType::SLUGS
  enum cycle_type: CycleType::SLUGS

  belongs_to :manufacturer

  has_many :bikes
  has_many :model_attestations
  has_many :organization_model_audits

  validates_uniqueness_of :frame_model, scope: %i[manufacturer_id manufacturer_other]

  before_validation :set_calculated_attributes

  def self.valid_kinds
    (certification_statuses.keys - ["certification_proof_url"])
  end

  def self.matching_bikes_for_bike(bike)
    bikes = Bike.unscoped.where(manufacturer_id: bike.manufacturer_id)
    bikes = bikes.where("frame_model ILIKE ?", bike.frame_model)
    if bike.manufacturer_id == Manufacturer.other.id
      bikes = bikes.where("mnfg_name ILIKE ?", bike.mnfg_name)
    end
    bikes.reorder(id: :desc)
  end

  def set_calculated_attributes
    self.manufacturer_other = nil if manufacturer_id != Manufacturer.other.id
    self.mnfg_name = Manufacturer.calculated_mnfg_name(manufacturer, manufacturer_other)
    self.certification_status = calculated_certification_status
  end

  private

  def calculated_certification_status
    (self.class.valid_kinds & model_attestations.distinct.pluck(:kind)).first
  end
end
