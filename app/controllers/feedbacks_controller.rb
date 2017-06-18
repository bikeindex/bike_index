class FeedbacksController < ApplicationController
  layout 'application_revised'
  before_filter :set_feedback_active_section
  before_filter :block_the_spam!, only: [:create]
  before_filter :set_permitted_format
  

  def index
    @feedback = Feedback.new
  end

  def create
    return true if block_the_spam!
    @feedback = Feedback.new(permitted_parameters)
    @feedback.user_id = current_user.id if current_user.present?
    if @feedback.save
      flash[:success] = 'Thanks for your message!'
      if request.env['HTTP_REFERER'].present? and request.env['HTTP_REFERER'] != request.env['REQUEST_URI']
        redirect_to :back
      else
        redirect_to help_path
      end
    else
      @page_errors = @feedback.errors
      re_path = Rails.application.routes.recognize_path(request.referer)
      @force_landing_page_render = re_path[:controller] == 'landing_pages'
      render template: "#{re_path[:controller]}/#{re_path[:action]}"
    end
  end

  def set_feedback_active_section
    @active_section = 'contact'
  end

  protected

  def block_the_spam!
    # Previously, we were authenticating users in a before_filter
    # But to make it possible for non-signed in users to generate leads, we're trying this out
    return false unless params[:feedback] && params[:feedback][:additional].present?
    flash[:error] = 'Please sign in to send that message'
    redirect_to feedbacks_path(anchor: 'contact_us_section') and return
  end


  def permitted_parameters
    params.require(:feedback).permit(%w(body email name title feedback_type feedback_hash).map(&:to_sym).freeze)
  end

  def set_permitted_format
    request.format = 'html'
  end
end
