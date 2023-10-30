class ModelTracker < ApplicationRecord
  enum certification_status: ModelAttestation::CERTIFICATION_KIND_ENUM
  enum propulsion_type: PropulsionType::SLUGS

  belongs_to :manufacturer

  has_many :bikes
  has_many :model_attestations

  validates_uniqueness_of :frame_model, scope: %i[manufacturer_id manufacturer_other]

  before_validation :set_calculated_attributes

  def self.valid_kinds
    (certification_statuses.keys - ["certification_proof_url"])
  end

  def set_calculated_attributes
    self.manufacturer_other = nil if manufacturer_id != Manufacturer.other.id
    self.certification_status = calculated_certification_status
  end

  private

  def calculated_certification_status
    (self.class.valid_kinds & model_attestations.distinct.pluck(:kind)).first
  end
end
