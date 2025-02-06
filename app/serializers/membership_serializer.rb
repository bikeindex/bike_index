class MembershipSerializer < ApplicationSerializer
  attributes :organization_name,
    :organization_id,
    :short_name,
    :slug,
    :is_admin,
    :base_url,
    :locations

  def organization_name
    object.organization.name
  end

  def short_name
    object.organization.short_name
  end

  def organization_id
    object.organization.id
  end

  def slug
    object.organization.slug
  end

  def is_admin
    object.role == "admin"
  end

  def base_url
    "/organizations/#{object.organization.slug}"
  end

  def locations
    if object.organization.locations && object.organization.locations.length > 1
      object.organization.locations.map do |location|
        {name: location.name, id: location.id}
      end
    else
      [{name: organization_name, id: nil}]
    end
  end
end
