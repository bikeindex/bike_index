class LandingPagesController < ApplicationController
  layout 'application_revised'
  before_filter :instantiate_feedback, except: [:show]
  def show
    raise ActionController::RoutingError, 'Not found' unless current_organization.present?
  end

  def for_law_enforcement; end

  def for_schools; end

  protected

  def instantiate_feedback
    @feedback ||= Feedback.new
  end
end
