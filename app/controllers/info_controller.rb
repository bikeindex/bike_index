class InfoController < ApplicationController
  layout 'application_revised'

  def about
  end

  def where
    @organizations = Organization.shown_on_map
  end

  def serials
  end

  def protect_your_bike
  end

  def lightspeed
    session[:return_to] = lightspeed_url unless current_user.present?
    @organization = Organization.new
  end

  def privacy
  end

  def terms
  end

  def vendor_terms
  end

  def resources
  end

  def image_resources
  end

  def support_bike_index
    @page_title = 'Support Bike Index'
    render layout: 'payments_layout'
  end

  def support_the_index
    redirect_to support_bike_index_url
  end

  def support_the_bike_index
    redirect_to support_the_index_url
  end

  def dev_and_design
  end

  def how_not_to_buy_stolen
    redirect_to 'https://files.bikeindex.org/stored/dont_buy_stolen.pdf'
  end
end
