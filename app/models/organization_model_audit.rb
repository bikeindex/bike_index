class OrganizationModelAudit < ApplicationRecord
  enum certification_status: ModelAttestation::CERTIFICATION_KIND_ENUM

  belongs_to :organization
  belongs_to :model_audit

  has_many :model_attestations, through: :model_audit

  before_validation :set_calculated_attributes

  validates_presence_of :organization_id
  validates_uniqueness_of :model_audit_id, scope: %i[organization_id], allow_nil: false

  # TODO: Maybe make this has_many
  def bikes
    organization.bikes.where(model_audit_id: model_audit_id)
  end

  def organization_model_attestations
    model_attestations.where(organization_id: organization_id)
      .order(:id)
  end

  def current_organization_model_attestation
    organization_model_attestations.current.last
  end

  def certification_status_humanized
    ModelAttestation.kind_humanized(certification_status)
  end

  def set_calculated_attributes
    self.certification_status = calculated_certification_status
  end

  private

  def calculated_certification_status
    if current_organization_model_attestation.present?
      current_organization_model_attestation.kind.gsub("trusted", "your")
    else
      model_audit&.certification_status
    end
  end
end
