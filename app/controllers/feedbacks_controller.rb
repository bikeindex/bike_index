class FeedbacksController < ApplicationController
  layout 'application_revised'
  before_filter :set_feedback_active_section
  before_filter :authenticate_user, only: [:new, :create]

  def index
    @feedback = Feedback.new
  end

  def new
  end

  def create
    @feedback = Feedback.new(permitted_parameters)
    if @feedback.save
      if @feedback.feedback_type == 'spokecard'
        flash[:notice] = "Thanks! We'll tell you as soon as we link your bike."
        redirect_to spokecard_path and return
      elsif @feedback.feedback_type == 'shop_submission'
        flash[:notice] = "Thanks! We'll set up the shop and give you a call."
        redirect_to where_path and return
      end
      redirect_to about_path, notice: 'Thanks for your comment!'
    else
      if @feedback.feedback_type == 'shop_submission'
        render action: :vendor_signup
      else
        render action: :new
      end
    end
  end

  def set_feedback_active_section
    @active_section = 'contact'
  end

  protected

  def permitted_parameters
    params.require(:feedback).permit(Feedback.old_attr_accessible)
  end
end
