class ModelAttestation < ApplicationRecord
  # NOTE: This hash is ordered by the importance of the kind
  CERTIFICATION_KIND_ENUM = {
    uncertified_by_trusted_org: 3,
    certified_by_trusted_org: 1,
    certified_by_manufacturer: 0,
    certification_proof_url: 2,
    certified_by_your_org: 10, # Only available on OrganizationModelAudits
    uncertified_by_your_org: 11
  }.freeze

  enum kind: CERTIFICATION_KIND_ENUM

  belongs_to :model_audit
  belongs_to :user
  belongs_to :organization

  validates_presence_of :model_audit_id
  validates_presence_of :kind
  validates_presence_of :user_id

  scope :current, -> { where(replaced: false) }

  before_validation :set_calculated_attributes
  after_commit :update_model_audit

  def update_model_audit
    UpdateModelAuditWorker.perform_async(model_audit_id)
    # Also lazy set the replaced attribute
    if id.present?
      ModelAttestation.where("id < ?", id)
        .where(organization_id: organization_id,
          model_audit_id: model_audit_id,
          replaced: false)
        .update_all(replaced: true)
    end
  end

  def set_calculated_attributes
    self.url = Urlifyer.urlify(url)
  end
end
