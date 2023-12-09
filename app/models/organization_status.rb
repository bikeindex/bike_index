class OrganizationStatus < AnalyticsRecord
  belongs_to :organization

  enum pos_kind: Organization::POS_KIND_ENUM
  enum kind: Organization::KIND_ENUM

  scope :current, -> { where(end_at: nil) }
  scope :ended, -> { where.not(end_at: nil) }
  scope :broken_pos, -> { where(pos_kind: Organization.broken_pos_kinds) }
  scope :with_pos, -> { where(pos_kind: Organization.with_pos_kinds) }
  scope :without_pos, -> { where(pos_kind: Organization.without_pos_kinds) }

  def current?
    end_at.blank?
  end

  def ended?
    !current?
  end
end
