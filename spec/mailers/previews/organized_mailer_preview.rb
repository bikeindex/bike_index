# Preview emails at http://localhost:3000/rails/mailers/organized_mailer
class OrganizedMailerPreview < ActionMailer::Preview
  def partial_registration
    b_param = BParam.last
    OrganizedMailer.partial_registration(b_param)
  end

  def finished_registration
    render_finished_registration(Bike.last)
  end

  def finished_registration_organization
    render_finished_registration(Bike.where.not(creation_organization_id: nil).first)
  end

  def finished_registration_stolen
    render_finished_registration(Bike.stolen.last)
  end

  def finished_registration_recovered
    render_finished_registration(Bike.where(recovered: true).last)
  end

  private

  def render_finished_registration(bike)
    OrganizedMailer.finished_registration(bike.current_ownership, bike: bike)
  end
end
