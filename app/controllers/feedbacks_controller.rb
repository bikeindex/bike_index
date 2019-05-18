class FeedbacksController < ApplicationController
  layout "application_revised"
  before_filter :set_feedback_active_section
  before_filter :set_permitted_format

  def index
    @feedback = Feedback.new
  end

  def create
    @feedback = Feedback.new(permitted_parameters)
    @feedback.user_id = current_user.id if current_user.present?
    return true if block_the_spam(@feedback)
    if @feedback.save
      if @feedback.lead?
        flash[:success] = "Thank you! We'll contact you soon."
      else
        flash[:success] = "Thanks for your message!"
      end
      if request.env["HTTP_REFERER"].present? and request.env["HTTP_REFERER"] != request.env["REQUEST_URI"]
        redirect_to :back
      else
        redirect_to help_path
      end
    else
      @page_errors = @feedback.errors
      re_path = Rails.application.routes.recognize_path(request.referer)
      template = "#{re_path[:controller]}/#{re_path[:action]}"
      @force_landing_page_render = re_path[:controller] == "landing_pages"
      @recovery_displays = RecoveryDisplay.limit(5) if template == "welcome/index"
      @page_id = [re_path[:controller], re_path[:action]].join("_")
      render template: template
    end
  end

  def set_feedback_active_section
    @active_section = "contact"
  end

  protected

  def block_the_spam(feedback)
    # Previously, we were authenticating users in a before_filter
    # But to make it possible for non-signed in users to generate leads, we're trying this out
    return false unless feedback.looks_like_spam?
    flash[:error] = "Please sign in to send that message"
    redirect_to :back and return true
  end

  def permitted_parameters
    params.require(:feedback).permit(:body, :email, :name, :title, :feedback_type, :feedback_hash,
                                     :package_size, :additional)
  end

  def set_permitted_format
    request.format = "html"
  end
end
