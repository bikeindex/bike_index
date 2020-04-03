class UpdateOrganizationPosKindWorker < ScheduledWorker
  prepend ScheduledWorkerRecorder
  sidekiq_options queue: "low_priority", retry: false

  def self.frequency
    6.3.hours
  end

  def perform(org_id = nil)
    return enqueue_workers unless org_id.present?
    organization = Organization.find(org_id)
    pos_kind = organization.calculated_pos_kind
    return true unless organization.pos_kind != pos_kind
    organization.update_attributes(pos_kind: pos_kind)
  end

  def enqueue_workers
    Organization.pluck(:id).each do |id|
      UpdateOrganizationPosKindWorker.perform_async(id)
    end
  end
end
