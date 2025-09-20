# == Schema Information
#
# Table name: model_attestations
#
#  id                 :bigint           not null, primary key
#  certification_type :string
#  file               :string
#  info               :text
#  kind               :integer
#  replaced           :boolean          default(FALSE)
#  url                :text
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  model_audit_id     :bigint
#  organization_id    :bigint
#  user_id            :bigint
#
# Indexes
#
#  index_model_attestations_on_model_audit_id   (model_audit_id)
#  index_model_attestations_on_organization_id  (organization_id)
#  index_model_attestations_on_user_id          (user_id)
#
class ModelAttestation < ApplicationRecord
  # NOTE: This hash is ordered by the importance of the kind
  CERTIFICATION_KIND_ENUM = {
    uncertified_by_trusted_org: 3,
    certified_by_trusted_org: 1,
    certified_by_manufacturer: 0,
    certification_proof_url: 2,
    certification_update: 4,
    certified_by_your_org: 10, # Only available on OrganizationModelAudits
    uncertified_by_your_org: 11
  }.freeze

  enum :kind, CERTIFICATION_KIND_ENUM

  belongs_to :model_audit
  belongs_to :user
  belongs_to :organization

  validates :model_audit_id, presence: true
  validates :kind, presence: true
  validates :user_id, presence: true

  mount_uploader :file, PdfUploader

  scope :current, -> { where(replaced: false) }
  scope :certification_updating, -> { where(kind: certification_update_kinds) }

  before_validation :set_calculated_attributes
  after_commit :update_model_audit

  def self.kind_humanized(str)
    return nil if str.blank?

    str.to_s.gsub("_org", " organization").tr("_", " ")
  end

  def self.certification_update_kinds
    %i[uncertified_by_trusted_org certified_by_trusted_org certified_by_manufacturer
      certified_by_your_org uncertified_by_your_org]
  end

  def kind_humanized
    self.class.kind_humanized(kind)
  end

  def update_model_audit
    UpdateModelAuditJob.perform_async(model_audit_id)
    # Also lazy set the replaced attribute
    previous_attesations.update_all(replaced: true)
  end

  def set_calculated_attributes
    self.url = Urlifyer.urlify(url)
    self.info = InputNormalizer.string(info)
    self.certification_type = InputNormalizer.string(certification_type)
  end

  private

  def previous_attesations
    return ModelAttestation.none if id.blank?

    ModelAttestation.where("id < ?", id)
      .where(organization_id: organization_id, model_audit_id: model_audit_id)
  end
end
