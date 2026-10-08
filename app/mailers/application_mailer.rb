class ApplicationMailer < ActionMailer::Base
  CONTACT_EMAIL = "contact@bikeindex.org".freeze
  CONTACT_BIKEINDEX = "\"Bike Index\" <#{CONTACT_EMAIL}>".freeze
  default from: CONTACT_BIKEINDEX, message_stream: "outbound"

  helper :mailer

  layout "email"
end
