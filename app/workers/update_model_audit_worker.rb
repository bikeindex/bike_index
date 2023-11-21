# This updates all matching bikes that ought to be updated
# saving bikes takes a LONG time - so this uses redlock to ensure we don't run duplicate jobs
class UpdateModelAuditWorker < ApplicationWorker
  REDLOCK_PREFIX = "ModelAuditLock-#{Rails.env.slice(0, 3)}"
  SKIP_PROCESSING = ENV["SKIP_UPDATE_MODEL_AUDIT"]

  sidekiq_options queue: "droppable", retry: 2

  # Not sure we actually want this method...
  def self.enqueue_for?(model_audit)
    return false if locked_for?(model_audit.id)
    return true if OrganizationModelAudit.missing_for?(model_audit)
    model_audit.bikes_count != model_audit.counted_matching_bikes_count
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
      matching_bikes = model_audit.matching_bikes
      # If there are 0 counted bikes, and should be deleted when there are no bikes:
      # update any non-counted bikes (e.g. likely_spam) and delete it
      counted_bikes = ModelAudit.counted_matching_bikes_count(matching_bikes)
      if counted_bikes == 0 && model_audit.delete_if_no_bikes?
        matching_bikes.update_all(model_audit_id: nil)
        model_audit.bikes.update_all(model_audit_id: nil)
        model_audit.destroy
        return
      end

      # Update bikes with manufacturer_other
      if model_audit.manufacturer_id == Manufacturer.other.id
        fix_manufacturer(model_audit, matching_bikes)
      end
      update_manufacturer = model_audit.manufacturer_id != Manufacturer.other.id

      other_model_audit_ids = matching_bikes.reorder(:model_audit_id).distinct.pluck(:model_audit_id).compact - [model_audit.id]
      # Assign all the matching bikes to the model_audit

      bikes_to_update(matching_bikes, model_audit).find_each do |bike|
        bike.manufacturer_id = model_audit.manufacturer_id if update_manufacturer
        bike.update(model_audit_id: model_audit.id)
      end
      other_model_audit_ids.each { |id| self.class.perform_async(id) }

      # Update all non_matching bikes (so they aren't accidentally processed in update_org_model_audit)
      non_matching_bike_ids = model_audit.bikes.pluck(:id) - matching_bikes.pluck(:id)
      Bike.unscoped.where(id: non_matching_bike_ids).update_all(model_audit_id: nil)
      # enqueue for any non-matching bikes. Space out processing, since non-matches might match each other
      non_matching_bike_ids.each_with_index do |id, inx|
        FindOrCreateModelAuditWorker.perform_in(inx * 15, id)
      end

      # Update the model_audit to set the certification_status, bikes_count and bust admin cache
      model_audit.reload.update(bikes_count: counted_bikes)

      OrganizationModelAudit.organizations_to_audit.pluck(:id)
        .each { |id| update_org_model_audit(model_audit, id) }
    ensure
      # Unlock!
      lock_manager.unlock(redlock)
    end
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

  def fix_manufacturer(model_audit, matching_bikes)
    existing_manufacturer = Manufacturer.friendly_find(model_audit.mnfg_name)
    existing_manufacturer ||= matching_bikes.where.not(manufacturer_id: Manufacturer.other.id).first&.manufacturer
    if existing_manufacturer.present? && !existing_manufacturer.other?
      model_audit.update(manufacturer_id: existing_manufacturer.id)
    end
  end

  def bikes_to_update(matching_bikes, model_audit)
    bikes = matching_bikes.where.not(model_audit_id: model_audit.id)
      .or(matching_bikes.where(model_audit_id: nil))
    return bikes if model_audit.manufacturer_id == Manufacturer.other.id
    bikes.or(matching_bikes.where(manufacturer_id: Manufacturer.other.id))
  end
end
