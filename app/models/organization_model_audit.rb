# == Schema Information
#
# Table name: organization_model_audits
#
#  id                   :bigint           not null, primary key
#  bikes_count          :integer          default(0)
#  certification_status :integer
#  last_bike_created_at :datetime
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  model_audit_id       :bigint
#  organization_id      :bigint
#
class OrganizationModelAudit < ApplicationRecord
  enum :certification_status, ModelAttestation::CERTIFICATION_KIND_ENUM

  belongs_to :organization
  belongs_to :model_audit

  has_many :model_attestations, through: :model_audit

  before_validation :set_calculated_attributes

  validates_presence_of :organization_id
  validates_uniqueness_of :model_audit_id, scope: %i[organization_id], allow_nil: false

  def self.organizations_to_audit
    # We enqueue every single model_audit when it's turned on for an org for the first time
    # ... So one we start creating model_audits, keep updating them
    existing_ids = OrganizationModelAudit.distinct.pluck(:organization_id)
    Organization.with_enabled_feature_slugs("model_audits")
      .or(Organization.where(id: existing_ids))
      .reorder(:id)
  end

  def self.missing_for?(model_audit)
    (organizations_to_audit.distinct.pluck(:id) -
      model_audit.organization_model_audits.pluck(:organization_id)).any?
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
    organization_model_attestations.current.certification_updating.last
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
