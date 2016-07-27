class FeedbacksController < ApplicationController
  layout 'application_revised'
  before_filter :set_feedback_active_section
  before_filter :authenticate_user, only: [:create]
  before_filter :set_permitted_format

  def index
    @feedback = Feedback.new
  end

  def create
    @feedback = Feedback.new(permitted_parameters)
    if @feedback.save
      # if @feedback.feedback_type == 'spokecard'
      #   flash[:notice] = "Thanks! We'll tell you as soon as we link your bike."
      #   redirect_to spokecard_path and return
      flash[:success] = 'Thanks for your feedback!'
      redirect_to help_path
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
    params.require(:feedback).permit(Feedback.old_attr_accessible)
  end

  def set_permitted_format
    request.format = 'html'
  end
end
