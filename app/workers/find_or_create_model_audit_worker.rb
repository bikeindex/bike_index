class FindOrCreateModelAuditWorker < ApplicationWorker
  sidekiq_options queue: "droppable", retry: 2

  def self.enqueue_for?(bike)
    return false if bike.example? || bike.deleted? || bike.likely_spam?
    return true if bike.model_audit_id.present?
    return true if ModelAudit.audit?(bike)
  end

  def perform(bike_id)
    bike = Bike.unscoped.find(bike_id)
    if bike.model_audit.present?
      if UpdateModelAuditWorker.enqueue_for?(bike.model_audit)
        UpdateModelAuditWorker.perform_async(bike.model_audit_id)
      end
      return
    end

    matching_bikes = ModelAudit.matching_bikes_for(bike)
    model_audit_ids = matching_bikes.reorder(:model_audit_id).distinct.pluck(:model_audit_id).compact.sort
    if model_audit_ids.any?
      # Assign model_audit_id to reduce the need to assign in UpdateModelAuditWorker
      bike.update(model_audit_id: model_audit_ids.first)
      model_audit_ids.each { |i| UpdateModelAuditWorker.perform_async(i) }
    elsif ModelAudit.counted_matching_bikes(matching_bikes).limit(1).none?
      # noop, there are no counted bikes
      return
    else
      model_audit = create_model_audit_for_bike(bike, matching_bikes)
      bike.update(model_audit_id: model_audit.id)
      UpdateModelAuditWorker.perform_async(model_audit.id)
    end
  end

  def create_model_audit_for_bike(bike, matching_bikes)
    propulsion_type = matching_bikes.detect { |b| b.propulsion_type != "foot-pedal" }&.propulsion_type
    propulsion_type ||= matching_bikes.first&.propulsion_type
    cycle_type = matching_bikes.detect { |b| b.cycle_type != "bike" }&.cycle_type
    cycle_type ||= matching_bikes.first&.cycle_type
    frame_model = ModelAudit.unknown_model?(bike.frame_model) ? nil : bike.frame_model
    ModelAudit.create!(manufacturer_id: bike.manufacturer_id,
      manufacturer_other: bike.manufacturer_other,
      frame_model: frame_model,
      propulsion_type: propulsion_type,
      cycle_type: cycle_type)
  end
end
