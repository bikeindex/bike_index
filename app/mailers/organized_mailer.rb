# Every email in here has the potential to be owned by an organization -
# but they aren't necessarily
class OrganizedMailer < ActionMailer::Base
  default from: '"Bike Index" <contact@bikeindex.org>',
          content_type: 'multipart/alternative',
          parts_order: ['text/calendar', 'text/plain', 'text/html', 'text/enriched']

  def partial_registration_email(b_param)
    @vars = {
      b_param_token: b_param.id_token
    }
    @send_to = b_param.owner_email
    @organization = b_param.creation_organization
    title = 'Finish your Bike Index registration!'
    mail('Reply-To' => reply_to, to: @send_to, subject: title) do |format|
      format.text
      format.html { render layout: 'email_no_border' }
    end
  end

  private

  def reply_to
    @organization && @organization.auto_user.present? ? @organization.auto_user.email : @send_to
  end
end
