class FindOrCreateModelAuditJob < ApplicationJob
  sidekiq_options queue: "droppable", retry: 2

  def self.enqueue_for?(bike)
    return false if bike.example? || bike.deleted? || bike.likely_spam?
    return true if bike.model_audit_id.present?

    ModelAudit.audit?(bike)
  end

  def perform(bike_id)
    bike = Bike.unscoped.find(bike_id)
    return if enqueue_existing_model_audit_update?(bike)

    fix_bike_manufacturer(bike) if bike.manufacturer_id == Manufacturer.other.id

    model_audit = ModelAudit.find_for(bike)
    if model_audit.blank?
      matching_bikes = ModelAudit.matching_bikes_for(bike)
      # If there are no counted bike (i.e. this bike is a non-counted bike), don't create a model_audit
      return if ModelAudit.counted_matching_bikes_count(matching_bikes) == 0

      model_audit = create_model_audit_for_bike(bike, matching_bikes)
    end
    bike.update(model_audit_id: model_audit.id)

    return unless UpdateModelAuditJob.enqueue_for?(model_audit.reload)

    UpdateModelAuditJob.perform_async(model_audit.id)
  end

  def enqueue_existing_model_audit_update?(bike)
    return if bike.model_audit_id.blank?

    if bike.model_audit&.matching_bike?(bike)
      if UpdateModelAuditJob.enqueue_for?(bike.model_audit)
        UpdateModelAuditJob.perform_async(bike.model_audit_id)
      end
      return true
    else
      UpdateModelAuditJob.perform_in(5, bike.model_audit_id)
      # Do a fast update, to make sure it updates later
      bike.update_attribute(:model_audit_id, nil)
    end
    false
  end

  def fix_bike_manufacturer(bike)
    existing_manufacturer = Manufacturer.friendly_find(bike.mnfg_name)
    if existing_manufacturer.present? && !existing_manufacturer.other?
      bike.update_attribute(:manufacturer_id, existing_manufacturer.id)
      bike.reload
    end
  end

  def create_model_audit_for_bike(bike, matching_bikes)
    propulsion_type = matching_bikes.detect { |b| b.propulsion_type != "foot-pedal" }&.propulsion_type
    propulsion_type ||= matching_bikes.first&.propulsion_type
    cycle_type = matching_bikes.detect { |b| b.cycle_type != "bike" }&.cycle_type
    cycle_type ||= matching_bikes.first&.cycle_type
    frame_model = if ModelAudit.unknown_model?(bike.frame_model, manufacturer_id: bike.manufacturer_id)
      nil
    else
      bike.frame_model
    end
    ModelAudit.create!(manufacturer_id: bike.manufacturer_id,
      manufacturer_other: bike.manufacturer_other,
      frame_model: frame_model,
      propulsion_type: propulsion_type,
      cycle_type: cycle_type)
  end
end
