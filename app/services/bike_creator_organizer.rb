class BikeCreatorOrganizer
  def initialize(b_param = nil, bike = nil)
    @b_param = b_param
    @bike = bike
  end

  def unorganize
    @bike.creation_organization_id = nil
  end

  def organization_usable(organization)
    if organization.is_suspended
      @bike.errors.add(:creation_organization, "Oh no! #{organization.name} is currently suspended. Contact us if this is a surprise.")
      return false
    end
    true
  end

  def find_organization(organization_id)
    begin
      organization = Organization.friendly_find(organization_id)
    rescue ActiveRecord::RecordNotFound
      @bike.errors.add(:creation_organization, "Uh oh, we couldn't find that organization. Try again?")
      return nil
    end
    organization
  end

  def organize(organization_id)
    organization = find_organization(organization_id)
    if organization.present? && organization_usable(organization)
      @bike.creation_organization_id = organization.id
      @bike.creator_id ||= organization.auto_user_id
    end
  end

  def check_organization
    if @b_param.params['creation_organization_id']
      organize(@b_param.params['creation_organization_id'])
    elsif @b_param.params['bike'].present? and @b_param.params['bike']['creation_organization_id']
      organize(@b_param.params['bike']['creation_organization_id'])
    else
      unorganize
    end
  end

  def organized_bike
    check_organization
    unorganize if @bike.errors.messages[:creation_organization].present?
    @bike
  end
end
