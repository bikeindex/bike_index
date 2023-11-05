class UpdateModelAuditWorker < ApplicationWorker
  sidekiq_options queue: "low_priority", retry: 2

  def self.enqueue_for?(bike)
    return true if bike.model_audit_id.present?
    return true if bike.motorized? && bike.frame_model.present?
    # Also enqueue if any matching bikes have a model_audit
    ModelAudit.matching_bikes_for_bike(bike).where.not(model_audit_id: nil).limit(1).any?
  end

  def perform(model_audit_id = nil, bike_id = nil)
    bike = Bike.unscoped.find_by_id(bike_id) if bike_id.present?
    model_audit_id ||= bike.model_audit_id

    if model_audit_id.present?
      model_audit = ModelAudit.find_by_id(model_audit_id)
    else
      matching_bikes = ModelAudit.matching_bikes_for_bike(bike)
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

    # Bump model_audit, unless it was just created
    model_audit.update(updated_at: Time.current) unless new_model_audit

    organization_ids_to_enqueue_for_model_audits.pluck(:id)
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
      organization_model_audit.update_attribute(bikes_count: bikes_count,
        last_bike_created_at: bike_at)
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

  def organization_ids_to_enqueue_for_model_audits
    # One we start creating model_audits, keep updating them
    # we enqueue every single model_audit when it's turned on for the first time,
    # so rather than tracking which to update, just update all of them
    (Organization.with_enabled_feature_slugs("model_audits") +
      OrganizationModelAudit.distinct.pluck(:organization_id)).uniq
  end

  def update_attrs(model_audit)
    model_audit.slice(:manufacturer_id, :manufacturer_other,
      :propulsion_type, :cycle_type)
      .merge(model_audit_id: model_audit.id)
  end
end
