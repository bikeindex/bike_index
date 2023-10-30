class ModelAttestation < ApplicationRecord
  # NOTE: This hash is ordered by the importance of the kind
  CERTIFICATION_KIND_ENUM = {
    uncertified_by_trusted_org: 3,
    certified_by_trusted_org: 1,
    certified_by_manufacturer: 0,
    certification_proof_url: 2
  }.freeze

  enum kind: CERTIFICATION_KIND_ENUM

  belongs_to :model_tracker
  belongs_to :user
  belongs_to :organization

  validates_presence_of :model_tracker_id
  validates_presence_of :kind
  validates_presence_of :user_id
end
