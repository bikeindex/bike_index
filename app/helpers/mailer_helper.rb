module MailerHelper
  # Whoever a paying organization covers - its emails, members, registrants and email domain - isn't
  # asked to donate on top of it. Organized::EmailsController renders the layout without a message
  def render_donation?
    !(@organization&.paid_money? || @user&.paid_organization? || Organization.paid_money_email_domain?(try(:message)&.to))
  end

  def render_supporters?(organization = nil)
    false
    # Disabled in PR#3616
    # if organization.present?
    #   return false if organization.bike_shop? || organization.paid_money?
    # end
    # true
  end
end
