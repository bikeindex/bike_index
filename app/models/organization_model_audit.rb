class OrganizationModelAudit < ApplicationRecord
  enum certification_status: ModelAttestation::CERTIFICATION_KIND_ENUM

  belongs_to :organization
  belongs_to :model_audit

  has_many :model_attestations, through: :model_audit

  before_validation :set_calculated_attributes

  validates_presence_of :organization_id
  validates_uniqueness_of :model_audit_id, scope: %i[organization_id], allow_nil: false

  def certification_status_humanized(str)
    return nil if str.blank?
    str.to_s.gsub("_", " ")
  end

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
    self.class.certification_status_humanized(certification_status)
  end

  def set_calculated_attributes
    self.certification_status = calculated_certification_status
  end

  private

  def calculated_certification_status
    current_organization_model_attestation&.kind || model_audit&.certification_status
  end
end
