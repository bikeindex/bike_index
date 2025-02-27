# Preview emails at /rails/mailers/organized_mailer
class OrganizedMailerPreview < ActionMailer::Preview
  def graduated_notification
    graduated_notification = GraduatedNotification.last
    OrganizedMailer.graduated_notification(graduated_notification)
  end

  def partial_registration
    b_param = BParam.order(:created_at).last
    OrganizedMailer.partial_registration(b_param)
  end

  def finished_registration
    unclaimed_unorganized_bikes = Bike.left_joins(:ownerships)
      .where(ownerships: {claimed: false})
      .unorganized

    render_finished_registration(unclaimed_unorganized_bikes)
  end

  def finished_registration_organization
    render_finished_registration(Bike.organized)
  end

  def finished_registration_stolen
    render_finished_registration(Bike.unscoped.status_stolen)
  end

  def finished_registration_abandoned
    render_finished_registration(Bike.status_abandoned)
  end

  def organization_invitation
    OrganizedMailer.organization_invitation(OrganizationRole.last)
  end

  def parking_notification
    OrganizedMailer.parking_notification(ParkingNotification.send_email.last)
  end

  def hot_sheet
    OrganizedMailer.hot_sheet(HotSheet.last)
  end

  def impound_claim_submitted
    OrganizedMailer.impound_claim_submitted(ImpoundClaim.submitted.last)
  end

  def impound_claim_approved_or_denied
    impound_claim = ImpoundClaim.where(status: %w[approved denied]).last
    OrganizedMailer.impound_claim_approved_or_denied(impound_claim)
  end

  private

  def render_finished_registration(bikes, bike = nil)
    bike ||= bikes.reorder(:created_at).limit(50).sample
    OrganizedMailer.finished_registration(bike.current_ownership)
  end
end
