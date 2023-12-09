class UpdateOrganizationPosKindWorker < ScheduledWorker
  prepend ScheduledWorkerRecorder
  sidekiq_options queue: "low_priority", retry: false

  def self.frequency
    6.3.hours
  end

  def perform(org_id = nil)
    return enqueue_workers unless org_id.present?
    organization = Organization.unscoped.find(org_id)
    pos_kind = organization.calculated_pos_kind
    organization_status = current_organization_status(organization)
    return true if organization.pos_kind == pos_kind
    organization_status.update(end_at: Time.current)
    organization.update(pos_kind: pos_kind)
    current_organization_status(organization)
  end

  def current_organization_status(organization)
    organization_status = OrganizationStatus.current.where(organization_id: organization.id).first
    if organization_status.present?
      return organization_status if organization_status.deleted? == organization.deleted?
    end
    OrganizationStatus.create!(organization_id: organization.id,
      kind: organization.kind,
      organization_deleted_at: organization.deleted_at,
      pos_kind: organization.pos_kind,
      start_at: organization.updated_at)
  end

  def create_organization_status(organization, pos_kind:)
  end

  def enqueue_workers
    Organization.unscoped.pluck(:id).each do |id|
      UpdateOrganizationPosKindWorker.perform_async(id)
    end
  end
end
