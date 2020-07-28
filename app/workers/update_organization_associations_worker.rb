# Because there are places that we have to call a bunch of organization saves, so background it

class UpdateOrganizationAssociationsWorker < ApplicationWorker
  def perform(org_ids)
    organization_ids_for_update = associated_organization_ids(org_ids)
    organization_ids_for_update.uniq.each do |id|
      organization = Organization.find(id)
      # Critical that locations skip_update, so we don't loop
      organization.locations.each { |l| l.update(updated_at: Time.current, skip_update: true) }
      organization.reload # Just in case default location has changed
      organization.update_attributes(skip_update: true, updated_at: Time.current)

      if organization.enabled?("impound_bikes_locations")
        # If there is isn't a default impound bikes location and there should be, set one
        if organization.locations.default_impound_locations.blank?
          default_location = organization.locations.impound_locations.first
          default_location.update(default_impound_location: true, skip_update: true) if default_location.present?
        elsif organization.locations.impound_locations.where(default_impound_location: true).count > 1
          # If there are more than one default locations, remove some
          organization.locations.impound_locations.where(default_impound_location: true).where.not(id: organization.default_impound_location.id)
            .each { |l| l.update(default_impound_location: false, skip_update: true) }
        end
      end

      organization.calculated_children.where.not(id: organization_ids_for_update)
        .each { |o| o.update_attributes(skip_update: true, updated_at: Time.current) }
    end
  end

  def associated_organization_ids(org_ids)
    organization_ids = [org_ids].flatten.map(&:to_i)

    # Find organizations that are a regional parents of an organization being updated
    regional_parents = Organization.regional.select { |organization|
      organization_ids.include?(organization.id) || (organization.nearby_organizations.pluck(:id) & organization_ids).any?
    }

    # If there was a regional organization passed, we need to update all of its children
    regional_child_ids = regional_parents.select { |o| organization_ids.include?(o.id) }
      .map { |o| o.nearby_organizations.pluck(:id) }

    # Also update standard parents
    parent_ids = organization_ids.map { |o| Organization.where(id: organization_ids).pluck(:parent_organization_id) }

    # Remove duplicates
    (organization_ids + parent_ids + regional_child_ids + regional_parents.map(&:id))
      .flatten.reject(&:blank?).compact.map(&:to_i).uniq
  end
end
