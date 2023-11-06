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
    else
      matching_bikes = ModelAudit.matching_bikes_for(bike)
      model_audit = matching_bikes.where.not(model_audit_id: nil).limit(1).first&.model_audit
      if model_audit.present?
        bike.update(update_attrs(model_audit))
      else
        new_model_audit = true
        model_audit = create_model_audit_for_bike(bike, matching_bikes)
        # if update_existing, matching bikes will be updated separately
        matching_bikes.find_each { |b| b.update(model_audit_id: model_audit.id) }
      end
    end

    return unless model_audit.present?

    update_existing_model_audit(model_audit) unless new_model_audit

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

    if bikes_count > 0 && organization_model_audit.blank?
      model_audit.organization_model_audits.create(bikes_count: bikes_count,
        organization_id: organization_id, last_bike_created_at: bike_at)
    elsif organization_model_audit.present?
      organization_model_audit.update(bikes_count: bikes_count,
        last_bike_created_at: bike_at)
    end
  end

  def create_model_audit_for_bike(bike, matching_bikes)
    propulsion_type = matching_bikes.detect { |b| b.propulsion_type != "foot-pedal" }&.propulsion_type
    propulsion_type ||= matching_bikes.first&.propulsion_type
    cycle_type = matching_bikes.detect { |b| b.cycle_type != "bike" }&.cycle_type
    cycle_type ||= matching_bikes.first&.cycle_type
    ModelAudit.create(manufacturer_id: bike.manufacturer_id,
      manufacturer_other: bike.manufacturer_other,
      frame_model: bike.frame_model,
      propulsion_type: propulsion_type,
      cycle_type: cycle_type)
  end

  def organization_ids_to_enqueue_for_model_audits
    # We enqueue every single model_audit when it's turned on for an org for the first time
    # ... So one we start creating model_audits, keep updating them
    (Organization.with_enabled_feature_slugs("model_audits").pluck(:id) +
      OrganizationModelAudit.distinct.pluck(:organization_id)).uniq
  end

  def update_existing_model_audit(model_audit)
    if model_audit.manufacturer_other.present?
      non_other_bike = model_audit.bikes.where.not(manufacturer_id: Manufacturer.other.id).first
      if non_other_bike.present?
        mnfg_id = non_other_bike.manufacturer_id
        mnfg_name = non_other_bike.mnfg_name
        model_audit.bikes.where(manufacturer_id: Manufacturer.other.id).each { |b| b.update(manufacturer_id: mnfg_id) }

        ModelAudit.matching_bikes_for(manufacturer_id: Manufacturer.other.id, mnfg_name: mnfg_name, frame_model: model_audit.frame_model)
          .each { |b| b.update(manufacturer_id: mnfg_id, model_audit_id: model_audit.id) }
        # Update model_audit afterward, so if this fails it will try to update the bikes again
        model_audit.manufacturer_id = mnfg_id
      end
    end
    model_audit.update(updated_at: Time.current)
  end

  def update_attrs(model_audit)
    model_audit.slice(:manufacturer_id, :manufacturer_other,
      :propulsion_type, :cycle_type)
      .merge(model_audit_id: model_audit.id)
  end
end
