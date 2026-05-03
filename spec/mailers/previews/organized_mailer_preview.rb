# Preview emails at /rails/mailers/organized_mailer.
#
# Each preview accepts an optional id query parameter so a specific record
# can be rendered (e.g. `?bike_id=1234`). Without one, the lookup falls
# back to the same heuristics as before — usually `Model.last`.
class OrganizedMailerPreview < ActionMailer::Preview
  def graduated_notification(graduated_notification_id: params[:graduated_notification_id])
    notification = graduated_notification_id ? GraduatedNotification.find(graduated_notification_id) : GraduatedNotification.last
    OrganizedMailer.graduated_notification(notification)
  end

  def partial_registration(b_param_id: params[:b_param_id])
    b_param = b_param_id ? BParam.find(b_param_id) : BParam.order(:created_at).last
    OrganizedMailer.partial_registration(b_param)
  end

  def finished_registration(bike_id: params[:bike_id])
    render_finished_registration(unclaimed_unorganized_bikes, bike_id:)
  end

  def finished_registration_transferred(bike_id: params[:bike_id])
    render_finished_registration(unclaimed_unorganized_bikes(not_initial: true), bike_id:)
  end

  def finished_registration_organization(bike_id: params[:bike_id])
    render_finished_registration(Bike.organized, bike_id:)
  end

  def finished_registration_stolen(bike_id: params[:bike_id])
    render_finished_registration(Bike.unscoped.status_stolen, bike_id:)
  end

  def finished_registration_abandoned(bike_id: params[:bike_id])
    render_finished_registration(Bike.status_abandoned, bike_id:)
  end

  def organization_invitation(organization_role_id: params[:organization_role_id])
    role = organization_role_id ? OrganizationRole.find(organization_role_id) : OrganizationRole.last
    OrganizedMailer.organization_invitation(role)
  end

  def parking_notification(parking_notification_id: params[:parking_notification_id])
    notification = parking_notification_id ? ParkingNotification.find(parking_notification_id) : ParkingNotification.send_email.last
    OrganizedMailer.parking_notification(notification)
  end

  def hot_sheet(hot_sheet_id: params[:hot_sheet_id])
    sheet = hot_sheet_id ? HotSheet.find(hot_sheet_id) : HotSheet.last
    OrganizedMailer.hot_sheet(sheet)
  end

  def impound_claim_submitted(impound_claim_id: params[:impound_claim_id])
    claim = impound_claim_id ? ImpoundClaim.find(impound_claim_id) : ImpoundClaim.submitted.last
    OrganizedMailer.impound_claim_submitted(claim)
  end

  def impound_claim_approved_or_denied(impound_claim_id: params[:impound_claim_id])
    claim = impound_claim_id ? ImpoundClaim.find(impound_claim_id) : ImpoundClaim.where(status: %w[approved denied]).last
    OrganizedMailer.impound_claim_approved_or_denied(claim)
  end

  private

  def render_finished_registration(bikes, bike_id: nil)
    bike = bike_id ? Bike.unscoped.find(bike_id) : bikes.reorder(:created_at).limit(50).sample
    OrganizedMailer.finished_registration(bike.current_ownership)
  end

  def unclaimed_unorganized_bikes(not_initial: false, status: :status_with_owner)
    bikes = Bike.left_joins(:current_ownership).where(ownerships: {claimed: false})
      .where(status:).unorganized

    if not_initial
      bikes.where.not(ownerships: {previous_ownership_id: nil})
    else
      bikes.where(ownerships: {previous_ownership_id: nil})
    end
  end
end
