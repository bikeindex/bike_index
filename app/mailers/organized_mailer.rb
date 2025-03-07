# Every email in here has the potential to be owned by an organization -
# but they aren't necessarily
class OrganizedMailer < ApplicationMailer
  helper TranslationHelper
  default content_type: "multipart/alternative",
    parts_order: ["text/calendar", "text/plain", "text/html", "text/enriched"]

  helper :organized
  helper :money # Required to render currency for bike recoveries
  helper :bike

  def partial_registration(b_param)
    @b_param = b_param
    @organization = @b_param.creation_organization

    I18n.with_locale(@user&.preferred_language) do
      mail(
        reply_to: reply_to,
        to: @b_param.owner_email,
        subject: default_i18n_subject(default_subject_vars),
        tag: __callee__
      )
    end
  end

  def finished_registration(ownership)
    # Things set here are also set in emails_controller - if updating, make sure to update there too
    @ownership = ownership
    @user = ownership.owner
    @bike = Bike.unscoped.find(@ownership.bike_id)
    @vars = {
      new_bike: @ownership.new_registration?,
      email: @ownership.owner_email,
      new_user: User.fuzzy_email_find(@ownership.owner_email).present?,
      registered_by_owner: @ownership.user.present? && @bike.creator_id == @ownership.user_id
    }
    @organization = @ownership.organization
    @vars[:donation_message] = @bike.status_stolen? && !(@organization && !@organization.paid?)
    subject = I18n.t("organized_mailer.finished#{finished_registration_type}_registration.subject", **default_subject_vars)
    tag = __callee__
    tag = "#{tag}_pos" if @ownership.pos? && @ownership.new_registration?
    I18n.with_locale(@user&.preferred_language) do
      mail(reply_to: reply_to,
        to: @vars[:email],
        subject: subject,
        tag: tag)
    end
  end

  def organization_invitation(organization_role)
    @organization_role = organization_role
    @organization = @organization_role.organization
    @sender = @organization_role.sender
    @vars = {email: @organization_role.invited_email}
    @new_user = User.fuzzy_email_find(@vars[:email]).present?

    I18n.with_locale(@sender&.preferred_language) do
      mail(reply_to: reply_to,
        to: @vars[:email],
        subject: default_i18n_subject(default_subject_vars),
        tag: __callee__)
    end
  end

  def parking_notification(parking_notification)
    @parking_notification = parking_notification
    @organization = @parking_notification.organization
    @bike = @parking_notification.bike
    @sender = @parking_notification.user

    I18n.with_locale(@sender&.preferred_language) do
      mail(reply_to: @parking_notification.reply_to_email,
        to: @parking_notification.email,
        tag: __callee__,
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

    I18n.with_locale(@user&.preferred_language) do
      mail(reply_to: reply_to,
        to: @graduated_notification.email,
        subject: @graduated_notification.subject,
        tag: __callee__)
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
      subject: @hot_sheet.subject,
      tag: __callee__)
  end

  def impound_claim_submitted(impound_claim)
    @impound_claim = impound_claim
    set_impound_claim_ivars
    mail(reply_to: "contact@bikeindex.org",
      to: @impound_claim.impound_record_email,
      subject: "New impound claim submitted",
      tag: __callee__)
  end

  def impound_claim_approved_or_denied(impound_claim)
    @impound_claim = impound_claim
    set_impound_claim_ivars
    mail(reply_to: impound_claim.impound_record_email,
      to: @impound_claim.user.email,
      subject: "Your impound claim was #{@impound_claim.status_humanized}",
      tag: __callee__)
  end

  private

  def finished_registration_type
    return "_stolen" if @bike.status_stolen?
    @ownership.claimed ? "_owned" : ""
  end

  def default_subject_vars
    {
      organization_name: @organization && "#{@organization.short_name} ",
      bike_type: @bike && "#{@bike.type} "
    }
  end

  def set_impound_claim_ivars
    @impound_record = @impound_claim.impound_record
    @organization = @impound_claim.organization
    @bike_claimed = @impound_claim.bike_claimed
    @bike_submitting = @impound_claim.bike_submitting
  end

  def reply_to
    (@organization && @organization.auto_user.present?) ? @organization.auto_user.email : "contact@bikeindex.org"
  end
end
