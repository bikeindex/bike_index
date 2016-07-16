class LandingPagesController < ApplicationController
  layout 'application_revised'
  def show
    raise ActionController::RoutingError, 'Not found' unless current_organization.present?
    @page_title = "#{current_organization.name} Bike Registration"
  end
end
