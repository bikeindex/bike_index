class ModelAttestation < ApplicationRecord
  # NOTE: This hash is ordered by the importance of the kind
  CERTIFICATION_KIND_ENUM = {
    uncertified_by_trusted_org: 3,
    certified_by_trusted_org: 1,
    certified_by_manufacturer: 0,
    certification_proof_url: 2
  }.freeze

  enum kind: CERTIFICATION_KIND_ENUM

  belongs_to :model_audit
  belongs_to :user
  belongs_to :organization

  validates_presence_of :model_audit_id
  validates_presence_of :kind
  validates_presence_of :user_id

  scope :current, -> { where(replaced: false) }

  after_commit :update_model_audit

  def update_model_audit
    UpdateModelAuditWorker.perform_async(model_audit_id)
  end
end
