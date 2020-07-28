# Every email in here has the potential to be owned by an organization -
# but they aren't necessarily
class OrganizedMailer < ApplicationMailer
  default content_type: "multipart/alternative",
          parts_order: ["text/calendar", "text/plain", "text/html", "text/enriched"]

  helper :organized

  def partial_registration(b_param)
    @b_param = b_param
    @organization = @b_param.creation_organization

    I18n.with_locale(@user&.preferred_language) do
      mail(
        reply_to: reply_to,
        to: @b_param.owner_email,
        subject: default_i18n_subject(default_subject_vars)
      )
    end
  end

  def finished_registration(ownership)
    # Things set here are also set in emails_controller - if updating, make sure to update there too
    @ownership = ownership
    @user = ownership.owner
    @bike = Bike.unscoped.find(@ownership.bike_id)
    @vars = {
      new_bike: (@bike.ownerships.count == 1),
      email: @ownership.owner_email,
      new_user: User.fuzzy_email_find(@ownership.owner_email).present?,
      registered_by_owner: (@ownership.user.present? && @bike.creator_id == @ownership.user_id)
    }
    @organization = @ownership.organization
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
    @vars = {email: @membership.invited_email}
    @new_user = User.fuzzy_email_find(@vars[:email]).present?

    I18n.with_locale(@sender&.preferred_language) do
      mail(reply_to: reply_to, to: @vars[:email], subject: default_i18n_subject(default_subject_vars))
    end
  end

  def parking_notification(parking_notification)
    @parking_notification = parking_notification
    @organization = @parking_notification.organization
    @bike = @parking_notification.bike
    @sender = @parking_notification.user
    @retrieval_link_url = if @parking_notification.retrieval_link_token.present?
      bike_url(@bike.to_param, parking_notification_retrieved: @parking_notification.retrieval_link_token)
    end

    I18n.with_locale(@sender&.preferred_language) do
      mail(reply_to: @parking_notification.reply_to_email,
           to: @parking_notification.email,
           subject: @parking_notification.subject) do |format|
        format.html { render "parking_notification" }
        format.text { render "parking_notification" }
      end
    end
  end

  def graduated_notification(graduated_notification)
    @graduated_notification = graduated_notification
    @organization = @graduated_notification.organization
    @bike = @graduated_notification.bike
    @retrieval_link_url = if @graduated_notification.marked_remaining_link_token.present?
      bike_url(@bike.to_param, graduated_notification_remaining: @graduated_notification.marked_remaining_link_token)
    end

    I18n.with_locale(@user&.preferred_language) do
      mail(reply_to: reply_to, to: @graduated_notification.email, subject: @graduated_notification.subject)
    end
  end

  def hot_sheet(hot_sheet, override_emails = nil)
    @hot_sheet = hot_sheet
    @organization = @hot_sheet.organization
    @stolen_records = @hot_sheet.fetch_stolen_records
    # Enable passing in email to make testing easier, ensure the emails are an array
    recipient_emails = Array(override_emails || @hot_sheet.recipient_emails)
    # Ensure we only email people once
    if recipient_emails.include?(reply_to)
      recipient_emails -= [reply_to] # remove original to address from
      direct_to = reply_to
    else
      direct_to = recipient_emails.shift
    end

    mail(reply_to: reply_to,
         to: direct_to,
         bcc: recipient_emails,
         subject: @hot_sheet.subject)
  end

  private

  def finished_registration_type
    return "_stolen" if @bike.stolen
    @ownership.claimed ? "_owned" : ""
  end

  def default_subject_vars
    {
      organization_name: @organization && "#{@organization.short_name} ",
      bike_type: @bike && "#{@bike.type} "
    }
  end

  def reply_to
    @organization && @organization.auto_user.present? ? @organization.auto_user.email : "contact@bikeindex.org"
  end
end
