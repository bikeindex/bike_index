class LandingPagesController < ApplicationController
  layout 'application_revised'
  before_action :force_html_response
  before_filter :instantiate_feedback, except: [:show]

  def show
    raise ActionController::RoutingError, 'Not found' unless current_organization.present?
  end

  def for_shops; end

  def for_advocacy; end

  def for_law_enforcement; end

  def for_schools; end

<<<<<<< HEAD
  def for_ascend; end
=======
  def ascend; @page_title ||= "Ascend POS on Bike Index" end
>>>>>>> fd0968c216e48a2b13d9f25268662d67e978729a

  def ambassadors_current; @page_title ||= 'Current Ambassadors' end

  def ambassadors_how_to; @page_title ||= 'Ambassadors' end

  protected

  def instantiate_feedback
    @feedback ||= Feedback.new
  end
end
