class ApplicationMailer < ActionMailer::Base
  CONTACT_BIKEINDEX = '"Bike Index" <contact@bikeindex.org>'.freeze
  default from: CONTACT_BIKEINDEX

  layout "email"
end
