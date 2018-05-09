class LandingPagesController < ApplicationController
  layout 'application_revised'
  before_filter :instantiate_feedback, except: [:show]

  def show
    raise ActionController::RoutingError, 'Not found' unless current_organization.present?
  end

  def for_shops; end

  def for_advocacy; end

  def for_law_enforcement; end

  def for_schools; end

  def ambassadors_current; @page_title ||= 'Current Ambassadors' end

  def ambassadors_how_to; @page_title ||= 'Ambassadors' end

  protected

  def instantiate_feedback
    @feedback ||= Feedback.new
  end
end
