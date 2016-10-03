class LandingPagesController < ApplicationController
  layout 'application_revised'
  def show
    raise ActionController::RoutingError, 'Not found' unless current_organization.present?
  end
end
