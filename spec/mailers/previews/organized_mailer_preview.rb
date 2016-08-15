# Preview emails at http://localhost:3000/rails/mailers/organized_mailer
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
    render_finished_registration(Bike.stolen)
  end

  def finished_registration_recovered
    render_finished_registration(Bike.where(recovered: true))
  end

  private

  def render_finished_registration(bikes)
    bike = bikes.order(:created_at).last
    OrganizedMailer.finished_registration(bike.current_ownership)
  end
end
