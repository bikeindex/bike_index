class ApplicationMailer < ActionMailer::Base
  CONTACT_EMAIL = "contact@bikeindex.org".freeze
  CONTACT_BIKEINDEX = "\"Bike Index\" <#{CONTACT_EMAIL}>".freeze
  default from: CONTACT_BIKEINDEX, message_stream: "outbound"

  helper :mailer
  helper_method :render_donation?

  layout "email"

  private

  # Whoever a paying organization covers - its emails, members, registrants and email domain - isn't
  # asked to donate on top of it
  def render_donation?
    !(@organization&.paid_money? || @user&.paid_organization? || Organization.paid_money_email_domain?(message.to))
  end
end
