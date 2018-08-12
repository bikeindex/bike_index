# Preview emails at /rails/mailers/organized_mailer
class OrganizedMailerPreview < ActionMailer::Preview
  def partial_registration
    b_param = BParam.order(:created_at).last
    OrganizedMailer.partial_registration(b_param)
  end

  def finished_registration
    render_finished_registration(Bike.unscoped)
  end

  def finished_registration_organization
    render_finished_registration(Bike.where.not(creation_organization_id: nil))
  end

  def finished_registration_stolen
    render_finished_registration(Bike.unscoped.stolen)
  end

  def finished_registration_recovered
    render_finished_registration(Bike.where(recovered: true))
  end

  def organization_invitation
    OrganizedMailer.organization_invitation(OrganizationInvitation.last)
  end

  def geolocated_message
    OrganizedMailer.custom_message(OrganizationMessage.geolocated.last)
  end

  private

  def render_finished_registration(bikes)
    bike = bikes.order(:created_at).last
    OrganizedMailer.finished_registration(bike.current_ownership)
  end
end
