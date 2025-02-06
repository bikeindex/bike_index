# == Schema Information
#
# Table name: organization_statuses
#
#  id                      :bigint           not null, primary key
#  end_at                  :datetime
#  kind                    :integer
#  organization_deleted_at :datetime
#  pos_kind                :integer
#  start_at                :datetime
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  organization_id         :bigint
#
# Indexes
#
#  index_organization_statuses_on_organization_id  (organization_id)
#
class OrganizationStatus < AnalyticsRecord
  belongs_to :organization

  enum :pos_kind, Organization::POS_KIND_ENUM
  enum :kind, Organization::KIND_ENUM

  has_one :notification, as: :notifiable

  scope :not_deleted, -> { where(organization_deleted_at: nil) }
  scope :deleted, -> { where.not(organization_deleted_at: nil) }
  scope :current, -> { where(end_at: nil) }
  scope :ended, -> { where.not(end_at: nil) }
  scope :broken_pos, -> { where(pos_kind: Organization.broken_pos_kinds) }
  scope :with_pos, -> { where(pos_kind: Organization.with_pos_kinds) }
  scope :without_pos, -> { where(pos_kind: Organization.without_pos_kinds) }

  def self.at_time(time)
    where("start_at < ?", time).where("end_at > ?", time)
      .or(current.where("start_at < ?", time))
  end

  def bulk_imports
    if Organization.ascend_or_broken_ascend_kinds.include?(pos_kind)
      b_imports = BulkImport.where("created_at > ?", start_at)
      ended? ? b_imports.where("created_at < ?", end_at) : b_imports
    else
      BulkImport.none
    end
  end

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
