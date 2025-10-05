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

  class << self
    def at_time(time)
      where("start_at < ?", time).where("end_at > ?", time)
        .or(current.where("start_at < ?", time))
    end

    def find_or_create_current(organization)
      organization_status = current.where(organization_id: organization.id).first

      return organization_status if unchanged?(organization_status:, organization:)

      if organization.deleted?
        # Don't create a new status for a deleted org. NOTE: this is the only time this method returns nil
        return unless organization_status.present?

        unless organization_status.deleted? && organization_status.end_at.present?
          organization_status.organization_deleted_at ||= organization.deleted_at
          organization_status.end_at ||= organization.deleted_at
          organization_status.save
        end
        return organization_status
      end

      new_organization_status = OrganizationStatus.create!(organization_id: organization.id,
        kind: organization.kind,
        organization_deleted_at: organization.deleted_at,
        pos_kind: organization.pos_kind,
        start_at: status_change_at(organization))

      organization_status&.update(end_at: new_organization_status.start_at)
      new_organization_status
    end

    private

    def unchanged?(organization:, organization_status: nil)
      return false if organization_status.blank?

      organization_status.deleted? == organization.deleted? &&
        organization_status.pos_kind == organization.pos_kind &&
        organization_status.kind == organization.kind
    end

    def status_change_at(organization)
      if %w[ascend_pos broken_ascend_pos].include?(organization.pos_kind)
        bulk_imports = BulkImport.where(organization_id: organization.id).ascend.order(:id)
        time = bulk_imports.no_import_errors.last&.created_at
        time ||= bulk_imports.file_errors.last&.created_at
        return time if time.present?
      end
      organization.updated_at || Time.current
    end
  end

  def bulk_imports
    return BulkImport.none unless Organization.ascend_or_broken_ascend_kinds.include?(pos_kind)

    b_imports = BulkImport.where("created_at > ?", start_at)
    ended? ? b_imports.where("created_at < ?", end_at) : b_imports
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
