class UpdateModelAuditWorker < ApplicationWorker
  sidekiq_options queue: "low_priority", retry: 2

  def self.enqueue_for?(bike)
    return true if bike.model_audit_id.present?
    bike.motorized? && bike.frame_model.present?
    # TODO: Also enqueue for bikes that match the manufacturer and frame_model
  end

  def perform(model_audit_id = nil, bike_id = nil)
    bike = Bike.unscoped.find_by_id(bike_id) if bike_id.present?
    model_audit_id ||= bike.model_audit_id
    if model_audit_id.present?
      model_audit = ModelAudit.find_by_id(model_audit_id)
    else
      matching_bikes = matching_bikes_for_bike(bike).order(created_at: :desc)
      model_audit = create_model_audit_for_bike(bike, matching_bikes)
      matching_bikes.find_each { |b| b.update(model_audit_id: model_audit.id) }
    end
  end

  def create_model_audit_for_bike(bike, matching_bikes)
    propulsion_type = matching_bikes.detect { |b| b.propulsion_type != "foot-pedal" }&.propulsion_type
    propulsion_type ||= matching_bikes.first&.propulsion_type
    cycle_type = matching_bikes.detect { |b| b.cycle_type != "bike" }&.cycle_type
    cycle_type ||= matching_bikes.first&.cycle_type
    model_audit = ModelAudit.create(manufacturer_id: bike.manufacturer_id,
      manufacturer_other: bike.manufacturer_other,
      frame_model: bike.frame_model,
      propulsion_type: propulsion_type,
      cycle_type: cycle_type)
  end

  def matching_bikes_for_bike(bike)
    bikes = Bike.unscoped.where("frame_model ILIKE ?", bike.frame_model)
    bikes = bikes.where(manufacturer_id: bike.manufacturer_id)
    # if bike.manfaucturer_other.
    bikes
  end
end
