class UpdateModelAuditWorker < ApplicationWorker
  sidekiq_options queue: "low_priority", retry: 2

  def self.enqueue_for?(bike)
    return true if bike.model_audit_id.present?
    return true if bike.motorized? && bike.frame_model.present?
    # Also enqueue if any matching bikes have a model_audit
    ModelAudit.matching_bikes_for(bike).where.not(model_audit_id: nil).limit(1).any?
  end

  def perform(model_audit_id = nil, bike_id = nil)
    bike = Bike.unscoped.find_by_id(bike_id) if bike_id.present?
    model_audit_id ||= bike.model_audit_id

    if model_audit_id.present?
      model_audit = ModelAudit.find_by_id(model_audit_id)
      matching_bikes = model_audit.matching_bikes
    else
      matching_bikes = ModelAudit.matching_bikes_for(bike)
      model_audit_ids = matching_bikes.reorder(:model_audit_id).distinct.pluck(:model_audit_id).compact.sort
      model_audit = if model_audit_ids.any?
        # Delete any extraneous model_audits separately
        if model_audit_ids.count > 1
          model_audit_ids[1..].each { |id| self.class.perform_async(id) }
        end
        ModelAudit.find(model_audit_ids.first)
      elsif ModelAudit.counted_matching_bikes(matching_bikes).limit(1).none?
        return # Because there are no counted bikes
      else
        new_model_audit = true
        create_model_audit_for_bike(bike, matching_bikes)
      end
    end
    # If there are 0 counted bikes, and should be deleted when there are no bikes:
    # update any non-counted bikes (e.g. likely_spam) and delete it
    if ModelAudit.counted_matching_bikes(matching_bikes).limit(1).blank? && model_audit.delete_if_no_bikes?
      matching_bikes.find_each { |b| b.update(model_audit_id: nil) }
      model_audit.destroy
      return
    end
    # Assign all the matching bikes to the model_audit
    matching_bikes.find_each { |b| b.update(model_audit_id: model_audit.id) }
    # Update bikes with manufacturer_other. If any bikes are updated, re-enqueue to prevent non_matching mixups
    if manufacturer_other_update(model_audit)
      return self.class.perform_async(model_audit.id)
    end
    # Update all non_matching bikes (so they aren't accidentally processed in update_org_model_audit)
    non_matching_bikes = model_audit.bikes.where.not(id: matching_bikes.pluck(:id))
    non_matching_bikes.update_all(model_audit_id: nil)
    # enqueue for any non-matching bikes. Space out processing, since non-matches might match each other
    non_matching_bikes.pluck(:id).each_with_index do |id, inx|
      self.class.perform_in(inx * 15, nil, id)
    end
    # Update the model_audit if hasn't been updated, to set the certification_status
    model_audit.update(updated_at: Time.current) unless new_model_audit
    organization_ids_to_enqueue_for_model_audits
      .each { |id| update_org_model_audit(model_audit, id) }
  end

  private

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
