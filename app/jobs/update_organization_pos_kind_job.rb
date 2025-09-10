class UpdateOrganizationPosKindJob < ScheduledJob
  prepend ScheduledJobRecorder

  sidekiq_options queue: "low_priority", retry: false

  def self.frequency
    6.3.hours
  end

  def self.calculated_pos_kind(organization)
    return organization.manual_pos_kind if organization.manual_pos_kind.present?

    bikes = organization.created_bikes # NOTE: Only created, so regional orgs don't get them
    recent_bikes = bikes.where(created_at: (Time.current - 1.week)..Time.current)
    if organization.ascend_name.present? || recent_bikes.ascend_pos.count > 0
      last_import = BulkImport.ascend.where(organization_id: organization.id).order(id: :desc).limit(1).last
      return last_import&.blocking_error? ? "broken_ascend_pos" : "ascend_pos"
    end
    return "lightspeed_pos" if recent_bikes.lightspeed_pos.count > 0
    return "other_pos" if recent_bikes.any_pos.count > 0

    if organization.bike_shop? && recent_bikes.count > 2
      return "does_not_need_pos" if organization.created_at < Time.current - 1.week ||
        bikes.where("bikes.created_at > ?", Time.current - 1.year).count > 100
    end
    return "broken_lightspeed_pos" if bikes.lightspeed_pos.count > 0

    (bikes.any_pos.count > 0) ? "broken_ascend_pos" : "no_pos"
  end

  def perform(org_id = nil)
    return enqueue_workers unless org_id.present?

    organization = Organization.unscoped.find(org_id)
    pos_kind = self.class.calculated_pos_kind(organization)
    organization_status = current_organization_status(organization)
    return true if organization.pos_kind == pos_kind

    status_change_at = status_change_at(organization)
    organization_status.update(end_at: status_change_at)
    organization.update(pos_kind: pos_kind)
    current_organization_status(organization, start_at: status_change_at)
  end

  private

  def current_organization_status(organization, start_at: nil)
    organization_status = OrganizationStatus.current.where(organization_id: organization.id).first
    if organization_status.present?
      return organization_status if organization_status.deleted? == organization.deleted?
    end
    OrganizationStatus.create!(organization_id: organization.id,
      kind: organization.kind,
      organization_deleted_at: organization.deleted_at,
      pos_kind: organization.pos_kind,
      start_at: start_at || Time.current)
  end

  def status_change_at(organization)
    if %w[ascend_pos broken_ascend_pos].include?(organization.pos_kind)
      bulk_imports = BulkImport.where(organization_id: organization.id).ascend.order(:id)
      time = bulk_imports.no_import_errors.last&.created_at
      time ||= bulk_imports.file_errors.last&.created_at
      return time if time.present?
    end
    organization.updated_at
  end

  def enqueue_workers
    Organization.unscoped.pluck(:id).each do |id|
      UpdateOrganizationPosKindJob.perform_async(id)
    end
  end
end
