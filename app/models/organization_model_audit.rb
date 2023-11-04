class OrganizationModelAudit < ApplicationRecord
  enum certification_status: ModelAttestation::CERTIFICATION_KIND_ENUM

  belongs_to :organization
  belongs_to :model_audit

  before_validation :set_calculated_attributes

  validates_presence_of :organization_id
  validates_uniqueness_of :model_audit_id, scope: %i[organization_id], allow_nil: false

  # TODO: Maybe make this (and model_attestations) has_many
  def bikes
    organization.bikes.where(model_audit_id: model_audit_id)
  end

  def model_attestations
    ModelAttestation.where(model_audit_id: model_audit_id, organization_id: organization_id)
      .order(:id)
  end

  def current_model_attestation
    model_attestations.current.last
  end

  def set_calculated_attributes
    self.certification_status = calculated_certification_status
  end

  private

  def calculated_certification_status
    current_model_attestation&.kind || model_audit&.certification_status
  end
end
