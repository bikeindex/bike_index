# Because there are places that we have to call a bunch of organization saves, so background it

class UpdateAssociatedOrganizationsWorker < ApplicationWorker
  def perform(org_ids)
    organization_ids_for_update = associated_organization_ids(org_ids)
    organization_ids_for_update.uniq.each do |id|
      organization = Organization.find(id)
      organization.update_attributes(skip_update: true, updated_at: Time.current)
      organization.calculated_children.where.not(id: organization_ids_for_update)
                  .each { |o| o.update_attributes(skip_update: true, updated_at: Time.current) }
    end
  end

  def associated_organization_ids(org_ids)
    organization_ids = [org_ids].flatten.map(&:to_i)

    # Find organizations that are a regional parents of an organization being updated
    regional_parents = Organization.regional.select do |organization|
      organization_ids.include?(organization.id) || (organization.nearby_organizations.pluck(:id) & organization_ids).any?
    end

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
