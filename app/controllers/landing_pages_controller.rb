class LandingPagesController < ApplicationController
  layout 'application_revised'
  before_filter :instantiate_feedback, except: [:show]
  before_filter :redirect_unless_preview_enabled?, only: [:for_schools, :for_law_enforcement]
  def show
    raise ActionController::RoutingError, 'Not found' unless current_organization.present?
  end

  def for_law_enforcement; end

  def for_schools; end

  protected

  def instantiate_feedback
    @feedback ||= Feedback.new
  end

  def redirect_unless_preview_enabled?
    unless preview_enabled?
      redirect_to user_root_url and return
    end
  end
end
