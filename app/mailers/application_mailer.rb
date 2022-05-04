class ApplicationMailer < ActionMailer::Base
  CONTACT_BIKEINDEX = '"Bike Index" <contact@bikeindex.org>'.freeze
  default from: CONTACT_BIKEINDEX, message_stream: "outbound"

  helper :mailer

  layout "email"
end
