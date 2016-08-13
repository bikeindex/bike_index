# Every email in here has the potential to be owned by an organization -
# but they aren't necessarily
class OrganizedMailer < ActionMailer::Base
  default from: '"Bike Index" <contact@bikeindex.org>',
          content_type: 'multipart/alternative',
          parts_order: ['text/calendar', 'text/plain', 'text/html', 'text/enriched']

  def partial_registration(b_param)
    @b_param = b_param
    @send_to = @b_param.owner_email
    @organization = @b_param.creation_organization
    mail('Reply-To' => reply_to, to: @send_to) do |format|
      format.text
      format.html { render layout: 'email_revised' }
    end
  end

  def finished_registration(ownership, bike: nil)
    @ownership = ownership
    @send_to = @ownership.owner_email
    @bike = bike || Bike.unscoped.find(@ownership.bike_id)
    @vars = {
      new_bike: (@bike.ownerships.count == 1),
      new_user: User.fuzzy_email_find(@ownership.owner_email).present?,
      registered_by_owner: (ownership.user.present? && @bike.creator_id == ownership.user_id),
    }
    @organization = @bike.creation_organization if @bike.creation_organization.present? && @vars[:new_bike]
    subject = t("organized_mailer.finished#{'_stolen' if @bike.stolen}_registration.subject", organization_name: nil)
    mail(to: @send_to, subject: subject) do |format|
      format.text
      format.html { render layout: 'email_revised' }
    end
  end

  # default_i18n_subject(user: user.name))

  private

  def reply_to
    @organization && @organization.auto_user.present? ? @organization.auto_user.email : @send_to
  end
end
