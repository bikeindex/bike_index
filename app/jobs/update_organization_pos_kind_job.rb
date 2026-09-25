class UpdateOrganizationPosKindJob < ScheduledJob
  prepend ScheduledJobRecorder

  sidekiq_options queue: "low_priority", retry: false

  POS_PROVIDERS = %w[lightspeed shopify].freeze # ascend has its own branch, above

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
      recent_provider = pos_provider_for(recent_bikes)
      return "#{recent_provider}_pos" if recent_provider.present?
      return "other_pos" if recent_bikes.any_pos.count > 0

      if organization.bike_shop?
        return "does_not_need_pos" if does_not_need_pos?(organization, bikes)
      end
      broken_provider = pos_provider_for(bikes)
      return "broken_#{broken_provider}_pos" if broken_provider.present?

      (bikes.any_pos.count > 0) ? "broken_ascend_pos" : "no_pos"
    end

    private

    # One list for both blocks - the fallback below labels anything unlisted "broken ascend",
    # so a provider added to only one of them mislabels orgs rather than failing
    def pos_provider_for(bikes)
      POS_PROVIDERS.find { bikes.public_send(:"#{it}_pos").exists? }
    end

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
