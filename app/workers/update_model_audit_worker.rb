class UpdateModelAuditWorker < ApplicationWorker
  sidekiq_options queue: "update_model_audit", retry: 2

  def self.enqueue_for?(bike)
    return false if bike.example? || bike.deleted? || bike.likely_spam?
    return true if bike.model_audit_id.present?
    return true if bike.motorized? && bike.frame_model.present?
    # Also enqueue if any matching bikes have a model_audit
    ModelAudit.matching_bikes_for(bike).where.not(model_audit_id: nil).limit(1).any?
  end

  def perform(model_audit_id = nil, bike_id = nil)
    model_audit, matching_bikes = model_audit_and_matching_bikes(model_audit_id, bike_id)
    return if model_audit.blank?
    # If there are 0 counted bikes, and should be deleted when there are no bikes:
    # update any non-counted bikes (e.g. likely_spam) and delete it
    if ModelAudit.counted_matching_bikes(matching_bikes).limit(1).blank? && model_audit.delete_if_no_bikes?
      matching_bikes.find_each { |b| b.update(model_audit_id: nil) }
      model_audit.bikes.find_each { |b| b.update(model_audit_id: nil) }
      model_audit.destroy
      # bike_id might have been passed - and if so, re-enqueue it if it should be
      if bike_id.present? && self.class.enqueue_for?(Bike.find_by_id(bike_id))
        self.class.perform_async(nil, bike_id)
      end
      return
    end
    other_model_audit_ids = matching_bikes.reorder(:model_audit_id).distinct.pluck(:model_audit_id).compact - [model_audit.id]
    # Assign all the matching bikes to the model_audit
    matching_bikes.where.not(model_audit_id: model_audit_id).or(matching_bikes.where(model_audit_id: nil)).find_each do |b|
      b.update(model_audit_id: model_audit.id)
    end
    other_model_audit_ids.each_with_index { |id, inx| self.class.perform_in(inx * 15, id) }
    # Update bikes with manufacturer_other. If any bikes are updated, re-enqueue to prevent non_matching mixups
    if manufacturer_other_update(model_audit)
      return self.class.perform_async(model_audit.id)
    end
    # Update all non_matching bikes (so they aren't accidentally processed in update_org_model_audit)
    non_matching_bike_ids = model_audit.bikes.pluck(:id) - matching_bikes.pluck(:id)
    Bike.unscoped.where(id: non_matching_bike_ids).update_all(model_audit_id: nil)
    # enqueue for any non-matching bikes. Space out processing, since non-matches might match each other
    non_matching_bike_ids.each_with_index { |id, inx| self.class.perform_in(inx * 15, nil, id) }
    # Update the model_audit to set the certification_status. Bust admin cache
    model_audit.reload.update(updated_at: Time.current)
    organization_ids_to_enqueue_for_model_audits
      .each { |id| update_org_model_audit(model_audit, id) }
  end

  private

  def model_audit_and_matching_bikes(model_audit_id, bike_id)
    bike = Bike.unscoped.find_by_id(bike_id) if bike_id.present?
    model_audit_id ||= bike.model_audit_id
    if model_audit_id.present?
      model_audit = ModelAudit.find_by_id(model_audit_id)
      matching_bikes = model_audit.matching_bikes
    else
      matching_bikes = ModelAudit.matching_bikes_for(bike)
      model_audit_ids = matching_bikes.reorder(:model_audit_id).distinct.pluck(:model_audit_id).compact.sort
      model_audit = if model_audit_ids.any?
        # Delete any extraneous model_audits
        # ModelAudit.where(id: model_audit_ids[1..]).destroy_all if model_audit_ids.count > 1
        if model_audit_ids.count > 1
          model_audit_ids[1..].each { |id| self.class.perform_async(id) }
        end
        ModelAudit.find(model_audit_ids.first)
      elsif ModelAudit.counted_matching_bikes(matching_bikes).limit(1).none?
        return # Because there are no counted bikes
      else
        create_model_audit_for_bike(bike, matching_bikes)
      end
    end
    [model_audit, matching_bikes]
  end

  def update_org_model_audit(model_audit, organization_id)
    bikes = Bike.where(model_audit_id: model_audit.id).left_joins(:bike_organizations)
      .where(bike_organizations: {organization_id: organization_id}).reorder(:id)
    bikes_count = bikes.count
    bike_at = bikes.last&.created_at || nil

    organization_model_audit = model_audit.organization_model_audits
      .where(organization_id: organization_id).first

    if organization_model_audit.blank?
      model_audit.organization_model_audits.create!(bikes_count: bikes_count,
        organization_id: organization_id, last_bike_created_at: bike_at)
    elsif organization_model_audit.present?
      organization_model_audit.update!(bikes_count: bikes_count,
        last_bike_created_at: bike_at)
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

  def organization_ids_to_enqueue_for_model_audits
    # We enqueue every single model_audit when it's turned on for an org for the first time
    # ... So one we start creating model_audits, keep updating them
    (Organization.with_enabled_feature_slugs("model_audits").pluck(:id) +
      OrganizationModelAudit.distinct.pluck(:organization_id)).uniq
  end

  def manufacturer_other_update(model_audit)
    mnfg_other_id = Manufacturer.other.id
    manufacturer = model_audit.manufacturer if model_audit.manufacturer_id != mnfg_other_id
    manufacturer ||= model_audit.bikes.where.not(manufacturer_id: mnfg_other_id).first&.manufacturer
    manufacturer ||= Manufacturer.friendly_find(model_audit.mnfg_name)
    return false if manufacturer.blank? || manufacturer.id == mnfg_other_id # Just in case friendly find...
    if model_audit.manufacturer_id == mnfg_other_id
      model_audit.update(manufacturer_id: manufacturer.id, manufacturer_other: nil)
    end
    bikes_updated = model_audit.bikes.where(manufacturer_id: mnfg_other_id).limit(1).present?
    model_audit.bikes.where(manufacturer_id: mnfg_other_id).each { |b| b.update(manufacturer_id: manufacturer.id) }
    bikes_updated
  end
end
