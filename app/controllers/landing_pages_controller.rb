class LandingPagesController < ApplicationController
  before_action :force_html_response
  before_action :instantiate_feedback, except: [:show]

  def show
    raise ActionController::RoutingError, "Not found" unless current_organization.present?
  end

  protected

  def instantiate_feedback
    @feedback ||= Feedback.new
  end
end
