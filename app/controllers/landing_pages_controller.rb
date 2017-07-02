class LandingPagesController < ApplicationController
  layout 'application_revised'
  before_filter :instantiate_feedback, except: [:show]
  before_filter :ensure_preview_enabled!, only: [:for_schools, :for_law_enforcement]
  before_filter :set_page_id, except: [:show]
  def show
    raise ActionController::RoutingError, 'Not found' unless current_organization.present?
  end

  def for_law_enforcement; end

  def for_schools; end

  protected

  def set_page_id
    @page_id = 'bike_index_landing'
  end

  def instantiate_feedback
    @feedback ||= Feedback.new
  end
end
