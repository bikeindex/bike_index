class PosIntegrationStatus < AnalyticsRecord
  belongs_to :organization

  enum pos_kind: Organization::POS_KIND_ENUM

  scope :current, -> { where(end_at: nil) }

  def current?
    end_at.blank?
  end
end
