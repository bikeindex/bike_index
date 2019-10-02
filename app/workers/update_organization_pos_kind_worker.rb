class UpdateOrganizationPosKindWorker < ScheduledWorker
  prepend ScheduledWorkerRecorder

  def self.frequency
    6.3.hours
  end

  def perform
    Organization.bike_shop.find_each do |organization|
      pos_kind = organization.calculated_pos_kind
      next unless organization.pos_kind != pos_kind
      organization.update_attributes(pos_kind: pos_kind)
    end
  end
end
