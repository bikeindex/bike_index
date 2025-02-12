# This updates all matching bikes that ought to be updated
# saving bikes takes a LONG time - so this uses redlock to ensure we don't run duplicate jobs
class UpdateModelAuditJob < ApplicationJob
  REDLOCK_PREFIX = "ModelAuditLock-#{Rails.env.slice(0, 3)}"
  SKIP_PROCESSING = ENV["SKIP_UPDATE_MODEL_AUDIT"].present?

  sidekiq_options queue: "droppable", retry: 2

  # Not sure we actually want this method...
  def self.enqueue_for?(model_audit)
    return false if locked_for?(model_audit.id)
    return true if OrganizationModelAudit.missing_for?(model_audit)
    model_audit.bikes_count != model_audit.counted_matching_bikes_count
  end

  def self.find_model_audit_id(model_audit)
    ModelAudit.find_for(nil, manufacturer_id: model_audit.manufacturer_id,
      mnfg_name: model_audit.mnfg_name, frame_model: model_audit.frame_model)&.id
  end

  # model_audit can be blank if it was deleted in fix_manufacturer_if_other!
  def self.delete_model_audit?(model_audit)
    return true if model_audit.blank? || find_model_audit_id(model_audit) != model_audit.id
    return false unless model_audit.delete_if_no_bikes?
    return true if model_audit.should_be_unknown_model? || model_audit.counted_matching_bikes_count == 0
    return false if model_audit.manufacturer&.motorized_only?
    ModelAudit.counted_matching_bikes(model_audit.matching_bikes).motorized.limit(1).none?
  end

  def self.redlock_key(model_audit_id)
    # Don't include both model_audit_id and bike_id in key
    bike_id = nil if model_audit_id.present?
    "#{REDLOCK_PREFIX}-#{model_audit_id}-#{bike_id}"
  end

  def self.new_lock_manager
    Redlock::Client.new([Bikeindex::Application.config.redis_default_url])
  end

  def self.locked_for?(model_audit_id)
    lock_manager = new_lock_manager
    lock_manager.locked?(redlock_key(model_audit_id))
  end

  def lock_duration_ms
    (20.minutes * 1000).to_i
  end

  def perform(model_audit_id = nil)
    return if SKIP_PROCESSING
    lock_manager = self.class.new_lock_manager
    redlock = lock_manager.lock(self.class.redlock_key(model_audit_id), lock_duration_ms)
    return unless redlock

    begin
      model_audit = ModelAudit.find_by(id: model_audit_id)
      return if model_audit.blank?

      fix_manufacturer!(model_audit) if model_audit.manufacturer_id == mnfg_other_id
      return delete_model_audit!(model_audit) if self.class.delete_model_audit?(model_audit)

      # model_audit.should_be_unknown_model?
      update_matching_bikes!(model_audit)

      # Update the model_audit to set the certification_status, bikes_count and bust admin cache
      model_audit.reload
      model_audit.update(bikes_count: model_audit.counted_matching_bikes_count)

      OrganizationModelAudit.organizations_to_audit.pluck(:id)
        .each { |id| update_org_model_audit(model_audit, id) }
    ensure
      # Unlock!
      lock_manager.unlock(redlock)
    end
  end

  private

  # Convenience
  def mnfg_other_id
    Manufacturer.other.id
  end

  def bikes(model_audit)
    Bike.unscoped.where(model_audit_id: model_audit.id)
  end

  def fix_manufacturer!(model_audit)
    existing_manufacturer = model_audit.bikes.where.not(manufacturer_id: mnfg_other_id).first&.manufacturer
    existing_manufacturer ||= Manufacturer.friendly_find(model_audit.mnfg_name)
    # Only can be fixed if there is a new matching manufacturer
    return if existing_manufacturer.blank? || existing_manufacturer.other?
    # If there is already a model_audit matching this, delete this model audit
    found_model_audit_id = self.class.find_model_audit_id(model_audit)
    if found_model_audit_id == model_audit.id
      # Update bikes first, so if this fails, it tries to fix_manufacturer again
      bikes(model_audit).where(manufacturer_id: mnfg_other_id).find_each do |bike|
        bike.update(manufacturer_id: existing_manufacturer.id)
      end
      model_audit.update!(manufacturer_id: existing_manufacturer.id)
    else
      bikes(model_audit).find_each do |bike|
        bike.update(model_audit_id: found_model_audit_id, manufacturer_id: existing_manufacturer.id)
      end
      model_audit.model_attestations
        .find_each { |att| att.update(model_audit_id: found_model_audit_id) }
    end
    model_audit.reload
  rescue ActiveRecord::RecordInvalid
    model_audit.destroy # Because the model audit already exists
  end

  def delete_model_audit!(model_audit)
    # Match any non-counted bikes (e.g. likely_spam)
    matching_bikes = Bike.unscoped.where(model_audit_id: model_audit.id)
    # Enqueue re-processing of the matching bikes if this should_be_unknown
    if model_audit.should_be_unknown_model?
      enqueue_delayed_processing_for_bike_ids(matching_bikes.pluck(:id))
    end

    matching_bikes.update_all(model_audit_id: nil)
    OrganizationModelAudit.where(model_audit_id: model_audit.id).destroy_all
    model_audit.destroy
  end

  # Maybe this should just enqueue all the non matching bikes??
  def update_matching_bikes!(model_audit)
    matching_bikes = model_audit.matching_bikes.reorder(:model_audit_id)
    model_audit_ids = matching_bikes.distinct.pluck(:model_audit_id).compact

    # Assign all the matching bikes to the model_audit
    matching_bikes.where.not(model_audit_id: model_audit.id)
      .or(matching_bikes.where(model_audit_id: nil))
      .find_each { |bike| bike.update(model_audit_id: model_audit.id) }

    (model_audit_ids - [model_audit.id]).each { |id| self.class.perform_async(id) }

    # Update all non_matching bikes (so they aren't accidentally processed in update_org_model_audit)
    non_matching_bike_ids = model_audit.bikes.pluck(:id) - matching_bikes.pluck(:id)
    Bike.unscoped.where(id: non_matching_bike_ids).update_all(model_audit_id: nil)
    # enqueue for any non-matching bikes
    enqueue_delayed_processing_for_bike_ids(non_matching_bike_ids)
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

  def enqueue_delayed_processing_for_bike_ids(bike_ids)
    # Space out processing, since bikes might match each other
    # Process 500 - that should cover the matching audits, but avoid overwhelming the queue
    bike_ids.sample(501).each_with_index do |id, inx|
      FindOrCreateModelAuditJob.perform_in(inx * 15 + 3, id)
    end
  end
end
