class OrganizationStatus < AnalyticsRecord
  belongs_to :organization

  enum pos_kind: Organization::POS_KIND_ENUM
  enum kind: Organization::KIND_ENUM

  scope :not_deleted, -> { where(organization_deleted_at: nil) }
  scope :deleted, -> { where.not(organization_deleted_at: nil) }
  scope :current, -> { not_deleted.where(end_at: nil) }
  scope :ended, -> { where.not(end_at: nil) }
  scope :broken_pos, -> { where(pos_kind: Organization.broken_pos_kinds) }
  scope :with_pos, -> { where(pos_kind: Organization.with_pos_kinds) }
  scope :without_pos, -> { where(pos_kind: Organization.without_pos_kinds) }

  def ended?
    end_at.present?
  end

  def deleted?
    organization_deleted_at.present?
  end

  def current?
    !ended? && !deleted?
  end
end
