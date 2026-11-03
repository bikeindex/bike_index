class LandingPagesController < ApplicationController
  before_action :force_html_response
  before_action :instantiate_feedback, except: [:show]

  def show
    raise ActionController::RoutingError, "Not found" unless current_organization.present?
  end

  protected

  def instantiate_feedback
    @feedback ||= Feedback.new(email: current_user&.email, contact_name: current_user&.name)
  end
end
