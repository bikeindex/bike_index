# Every email in here has the potential to be owned by an organization -
# but they aren't necessarily
class OrganizedMailer < ApplicationMailer
  default content_type: "multipart/alternative",
          parts_order: ["text/calendar", "text/plain", "text/html", "text/enriched"]

  def partial_registration(b_param)
    @b_param = b_param
    @organization = @b_param.creation_organization

    I18n.with_locale(@user&.preferred_language) do
      mail(
        reply_to: reply_to,
        to: @b_param.owner_email,
        subject: default_i18n_subject(default_subject_vars),
      )
    end
  end

  def finished_registration(ownership)
    @ownership = ownership
    @user = ownership.owner
    @bike = Bike.unscoped.find(@ownership.bike_id)
    @vars = {
      new_bike: (@bike.ownerships.count == 1),
      email: @ownership.owner_email,
      new_user: User.fuzzy_email_find(@ownership.owner_email).present?,
      registered_by_owner: (@ownership.user.present? && @bike.creator_id == @ownership.user_id),
    }
    @organization = @bike.creation_organization if @bike.creation_organization.present? && @vars[:new_bike]
    @vars[:donation_message] = @bike.stolen? && !(@organization && !@organization.is_paid?)
    subject = t("organized_mailer.finished#{finished_registration_type}_registration.subject", default_subject_vars)

    I18n.with_locale(@user&.preferred_language) do
      mail(reply_to: reply_to, to: @vars[:email], subject: subject)
    end
  end

  def organization_invitation(membership)
    @membership = membership
    @organization = @membership.organization
    @sender = @membership.sender
    @vars = { email: @membership.invited_email }
    @new_user = User.fuzzy_email_find(@vars[:email]).present?

    I18n.with_locale(@sender&.preferred_language) do
      mail(reply_to: reply_to, to: @vars[:email], subject: default_i18n_subject(default_subject_vars))
    end
  end

  def custom_message(organization_message)
    @organization_message = organization_message
    @organization = @organization_message.organization
    @bike = @organization_message.bike
    @sender = @organization_message.sender

    subject = default_i18n_subject(
      org_name: @organization.short_name,
      mnfg_name: @bike.mnfg_name,
    )

    I18n.with_locale(@sender&.preferred_language) do
      mail(reply_to: @organization_message.sender.email,
           to: @organization_message.email,
           subject: subject) do |format|
        format.html { render "geolocated_message" }
        format.text { render "geolocated_message" }
      end
    end
  end

  private

  def finished_registration_type
    return "_stolen" if @bike.stolen
    @ownership.claimed ? "_owned" : ""
  end

  def default_subject_vars
    {
      organization_name: @organization && "#{@organization.short_name} ",
      bike_type: @bike && "#{@bike.type} ",
    }
  end

  def reply_to
    @organization && @organization.auto_user.present? ? @organization.auto_user.email : "contact@bikeindex.org"
  end
end
