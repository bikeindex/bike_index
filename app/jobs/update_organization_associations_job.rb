# Because there are places that we have to call a bunch of organization saves, so background it

class UpdateOrganizationAssociationsJob < ApplicationJob
  def perform(org_ids)
    organization_ids_for_update = associated_organization_ids(org_ids)

    organization_ids_for_update.each do |id|
      organization = Organization.find(id)
      # Critical that locations skip_update, so we don't loop
      organization.locations.each { |l| l.update(updated_at: Time.current, skip_update: true) }
      organization.reload # Just in case default location has changed
      organization.update(skip_update: true, updated_at: Time.current)
      add_organization_manufacturers(organization)
      update_organization_stolen_message(organization)

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

      # Only enqueue this if there aren't any org model audits, because this will be a lot
      if organization.enabled?("model_audits") && organization.organization_model_audits.limit(1).none?
        organization.bikes.where.not(bikes: {model_audit_id: nil}).pluck(:model_audit_id)
          .each { |id| UpdateModelAuditJob.perform_async(id) }
      end

      organization.calculated_children.where.not(id: organization_ids_for_update)
        .each { |o| o.update(skip_update: true, updated_at: Time.current) }

      # Update mailchimp datum for organizations
      organization.admins.each { |u| MailchimpDatum.find_and_update_or_create_for(u) }
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
    parent_ids = organization_ids.map { |o| Organization.where(id: o).pluck(:parent_organization_id) }

    # Remove duplicates
    (organization_ids + parent_ids + regional_child_ids + regional_parents.map(&:id))
      .flatten.map(&:to_i).reject { |i| i == 0 }.uniq
  end

  def add_organization_manufacturers(organization)
    return unless organization.bike_shop?
    manufacturer_ids = Organization.with_enabled_feature_slugs("official_manufacturer")
      .where.not(manufacturer_id: nil).pluck(:manufacturer_id)
    new_manufacturer_ids = manufacturer_ids - organization.organization_manufacturers.pluck(:manufacturer_id)
    new_manufacturer_ids.each do |manufacturer_id|
      next unless organization.bikes.where(manufacturer_id: manufacturer_id).any?
      OrganizationManufacturer.create(manufacturer_id: manufacturer_id,
        organization_id: organization.id)
    end
  end

  def update_organization_stolen_message(organization)
    if organization.enabled?("organization_stolen_message")
      OrganizationStolenMessage.for(organization) # Create if it doesn't exist
    elsif organization.organization_stolen_message&.is_enabled?
      organization.organization_stolen_message.update(is_enabled: false)
    end
  end
end
