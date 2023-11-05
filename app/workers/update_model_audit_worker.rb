class UpdateModelAuditWorker < ApplicationWorker
  sidekiq_options queue: "low_priority", retry: 2

  def self.enqueue_for?(bike)
    return true if bike.model_audit_id.present?
    pp bike.motorized?
    bike.motorized?
  end

  def perform(model_audit_id = nil, bike_id = nil)

  end
end
