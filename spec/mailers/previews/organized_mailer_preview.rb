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
    render_finished_registration(Bike.organized)
  end

  def finished_registration_stolen
    render_finished_registration(Bike.unscoped.stolen)
  end

  def finished_registration_abandoned
    render_finished_registration(Bike.where(abandoned: true))
  end

  def organization_invitation
    OrganizedMailer.organization_invitation(OrganizationInvitation.last)
  end

  def parking_notification
    OrganizedMailer.parking_notification(ParkingNotification.send_email.last)
  end

  private

  def render_finished_registration(bikes)
    bike = Organization.friendly_find("psu").created_bikes.order(:created_at).last
    bike ||= bikes.order(:created_at).last
    OrganizedMailer.finished_registration(bike.current_ownership)
  end
end
