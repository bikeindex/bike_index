class OrganizationModelAudit < ApplicationRecord
  enum certification_status: ModelAttestation::CERTIFICATION_KIND_ENUM

  belongs_to :organization
  belongs_to :model_audit

  has_many :model_attestations, through: :model_audit

  before_validation :set_calculated_attributes

  validates_presence_of :organization_id
  validates_uniqueness_of :model_audit_id, scope: %i[organization_id], allow_nil: false

  def bikes

  end

  def set_calculated_attributes
    self.certification_status = calculated_certification_status
  end

  private

  def calculated_certification_status
    # (self.class.valid_kinds & model_attestations.distinct.pluck(:kind)).first
  end
end
