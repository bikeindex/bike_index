class ApplicationMailer < ActionMailer::Base
  CONTACT_BIKEINDEX = '"Bike Index" <contact@bikeindex.org>'.freeze
  default from: CONTACT_BIKEINDEX
  before_action :assign_render_donation_and_supporters

  def assign_render_donation_and_supporters
    @render_donation = true
    @render_supporters = true
  end

  layout "email"
end
