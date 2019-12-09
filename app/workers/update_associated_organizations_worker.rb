# Because there are places that we have to call a bunch of organization saves, so background it

class UpdateAssociatedOrganizationsWorker < ApplicationWorker
  def perform(organization_ids)
    organization_ids = [organization_ids].flatten
    # Find regional orgs that should also be updated, based on whether they match an organization being updated
    regional_ids_to_update = Organization.regional.where.not(id: organization_ids)
                                         .select { |o| o.nearby_organizations.pluck(:id) }
                                         .map(&:id)
    parent_ids = organization_ids.map { |o| Organization.where(id: organization_ids).pluck(:parent_organization_id) }

    # Remove duplicates
    uniq_ids = (organization_ids + parent_ids + regional_ids_to_update).flatten.reject(&:blank?).compact.map(&:to_i).uniq

    # Only update organizations once
    uniq_ids.uniq.each do |id|
      organization = Organization.find(id)
      organization.update_attributes(skip_update: true, updated_at: Time.current)
      organization.calculated_children.where.not(id: uniq_ids)
                  .each { |o| o.update_attributes(updated_at: Time.current, skip_update: true) }
    end
  end
end
