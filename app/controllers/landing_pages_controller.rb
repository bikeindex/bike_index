class LandingPagesController < ApplicationController
  layout 'application_revised'
  def show
    raise ActionController::RoutingError, 'Not found' unless current_organization.present?
    @page_title = "#{current_organization.short_name} Bike Registration"
  end
end
