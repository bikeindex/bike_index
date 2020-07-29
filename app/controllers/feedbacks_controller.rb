class FeedbacksController < ApplicationController
  before_action :set_feedback_active_section
  before_action :set_permitted_format

  def index
    @feedback = Feedback.new
  end

  def create
    @feedback = Feedback.new(permitted_parameters)
    @feedback.user_id = current_user.id if current_user.present?
    return true if block_the_spam(@feedback)

    if @feedback.save
      flash[:success] = if @feedback.lead?
        translation(:we_will_contact_you)
      else
        translation(:thanks_for_your_message)
      end
      if request.env["HTTP_REFERER"].present? && (request.env["HTTP_REFERER"] != request.env["REQUEST_URI"])
        redirect_back(fallback_location: help_path)
      else
        redirect_to help_path
      end
    else
      @page_errors = @feedback.errors
      render(:index) && return if request.referer.blank?

      re_path = Rails.application.routes.recognize_path(request.referer)
      template = "#{re_path[:controller]}/#{re_path[:action]}"
      @force_landing_page_render = re_path[:controller] == "landing_pages"
      @page_id = [re_path[:controller], re_path[:action]].join("_")
      @recovery_displays = RecoveryDisplay.limit(5) if template == "welcome/index"
      render template: template
    end
  end

  def set_feedback_active_section
    @active_section = "contact"
  end

  protected

  def block_the_spam(feedback)
    # Previously, we were authenticating users in a before_action
    # But to make it possible for non-signed in users to generate leads, we're trying this out
    return false unless feedback.looks_like_spam?
    flash[:error] = translation(:please_sign_in)
    redirect_back(fallback_location: root_url) && (return true)
  end

  def permitted_parameters
    params.require(:feedback).permit(:body, :email, :name, :title, :feedback_type, :feedback_hash,
      :package_size, :phone_number, :additional)
  end

  def set_permitted_format
    request.format = "html"
  end
end
