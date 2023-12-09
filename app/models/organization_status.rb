class OrganizationStatus < AnalyticsRecord
  belongs_to :organization

  enum pos_kind: Organization::POS_KIND_ENUM
  enum kind: Organization::KIND_ENUM

  scope :current, -> { where(end_at: nil) }

  def current?
    end_at.blank?
  end
end
