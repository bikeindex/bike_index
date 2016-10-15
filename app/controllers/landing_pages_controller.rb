class LandingPagesController < ApplicationController
  layout 'application_revised'
  def show
    raise ActionController::RoutingError, 'Not found' unless current_organization.present?
  end

  def for_law_enforcement
  end

  def for_schools
  end
end
