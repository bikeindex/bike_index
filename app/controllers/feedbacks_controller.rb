class FeedbacksController < ApplicationController
  layout 'application_revised'
  before_filter :set_feedback_active_section
  # before_filter :authenticate_user, only: [:create] # provisionally off
  before_filter :set_permitted_format

  def index
    @feedback = Feedback.new
  end

  def create
    @feedback = Feedback.new(permitted_parameters)
    @feedback.user_id = current_user.id if current_user.present?
    if @feedback.save
      # if @feedback.feedback_type == 'spokecard'
      #   flash[:notice] = "Thanks! We'll tell you as soon as we link your bike."
      #   redirect_to spokecard_path and return
      flash[:success] = 'Thanks for your message!'
      if request.env['HTTP_REFERER'].present? and request.env['HTTP_REFERER'] != request.env['REQUEST_URI']
        redirect_to :back
      else
        redirect_to help_path
      end
    else
      @page_errors = @feedback.errors
      render action: :index
    end
  end

  def set_feedback_active_section
    @active_section = 'contact'
  end

  protected

  def permitted_parameters
    params.require(:feedback).permit(%w(body email name title feedback_type feedback_hash).map(&:to_sym).freeze)
  end

  def set_permitted_format
    request.format = 'html'
  end
end
