# Every email in here has the potential to be owned by an organization -
# but they aren't necessarily
class OrganizedMailer < ActionMailer::Base
  CONTACT_BIKEINDEX = 'Bike Index <contact@bikeindex.org>'.freeze
  default from: CONTACT_BIKEINDEX,
          content_type: 'multipart/alternative',
          parts_order: ['text/calendar', 'text/plain', 'text/html', 'text/enriched']
  layout 'email'

  def partial_registration(b_param)
    @b_param = b_param
    @organization = @b_param.creation_organization
    mail('Reply-To' => reply_to, to: @b_param.owner_email, subject: default_i18n_subject(default_subject_vars))
  end

  def finished_registration(ownership)
    @ownership = ownership
    @bike = Bike.unscoped.find(@ownership.bike_id)
    @vars = {
      new_bike: (@bike.ownerships.count == 1),
      new_user: User.fuzzy_email_find(@ownership.owner_email).present?,
      registered_by_owner: (@ownership.user.present? && @bike.creator_id == @ownership.user_id),
    }
    @organization = @bike.creation_organization if @bike.creation_organization.present? && @vars[:new_bike]
    @vars[:donation_message] = @bike.stolen? && !(@organization && !@organization.is_paid?)
    subject = t("organized_mailer.finished#{finished_registration_type}_registration.subject", default_subject_vars)
    mail('Reply-To' => reply_to, to: @ownership.owner_email, subject: subject)
  end

  def organization_invitation(organization_invitation)
    @organization_invitation = organization_invitation
    @organization = @organization_invitation.organization
    @inviter = @organization_invitation.inviter
    @new_user = User.fuzzy_email_find(@organization_invitation.invitee_email).present?
    mail('Reply-To' => reply_to, to: @organization_invitation.invitee_email, subject: default_i18n_subject(default_subject_vars))
  end

  def custom_message(organization_message)
    @organization_message = organization_message
    @organization = @organization_message.organization
    @bike = @organization_message.bike
    @sender = @organization_message.sender

    mail('Reply-To' => @organization_message.sender.email, to: @organization_message.email, subject: @organization_message.subject) do |format|
      format.html { render "geolocated_message" }
      format.text { render "geolocated_message_text" }
    end
  end

  private

  def finished_registration_type
    return '_stolen' if @bike.stolen
    @ownership.claimed ? '_owned' : ''
  end

  def default_subject_vars
    {
      organization_name: @organization && "#{@organization.short_name} ",
      bike_type: @bike && "#{@bike.type} "
    }
  end

  def reply_to
    @organization && @organization.auto_user.present? ? @organization.auto_user.email : CONTACT_BIKEINDEX
  end
end
