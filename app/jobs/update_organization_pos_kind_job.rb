class UpdateOrganizationPosKindJob < ScheduledJob
  prepend ScheduledJobRecorder

  sidekiq_options queue: "low_priority", retry: false

  class << self
    def frequency
      6.3.hours
    end

    def calculated_pos_kind(organization)
      return organization.manual_pos_kind if organization.manual_pos_kind.present?

      bikes = organization.created_bikes # NOTE: Only created, so regional orgs don't get them
      recent_bikes = bikes.where(created_at: (Time.current - 1.week)..Time.current)
      if organization.ascend_name.present? || recent_bikes.ascend_pos.count > 0
        last_import = BulkImport.ascend.where(organization_id: organization.id).order(id: :desc).limit(1).last
        return last_import&.blocking_error? ? "broken_ascend_pos" : "ascend_pos"
      end
      return "lightspeed_pos" if recent_bikes.lightspeed_pos.count > 0
      return "other_pos" if recent_bikes.any_pos.count > 0

      if organization.bike_shop?
        return "does_not_need_pos" if does_not_need_pos?(organization, bikes)
      end
      return "broken_lightspeed_pos" if bikes.lightspeed_pos.count > 0

      (bikes.any_pos.count > 0) ? "broken_ascend_pos" : "no_pos"
    end

    private

    # Try to prevent churn in does_not_need_pos designation
    def does_not_need_pos?(organization, bikes)
      # Don't set the status if the org is new, so the POS message is shown in the org interface
      return false if organization.created_at > Time.current - 2.weeks

      bikes.where("bikes.created_at > ?", Time.current - 1.month).count > 9 ||
        bikes.where("bikes.created_at > ?", Time.current - 1.year).count > 100
    end
  end

  def perform(org_id = nil)
    return enqueue_workers unless org_id.present?

    organization = Organization.unscoped.find(org_id)
    pos_kind = self.class.calculated_pos_kind(organization)

    organization.update(pos_kind: pos_kind) if organization.pos_kind != pos_kind
    OrganizationStatus.find_or_create_current(organization.reload)
  end

  private

  def enqueue_workers
    Organization.unscoped.pluck(:id).each do |id|
      UpdateOrganizationPosKindJob.perform_async(id)
    end
  end
end
