class FeedbacksController < ApplicationController
  layout 'content'
  before_filter :set_feedback_active_section

  def new
    @title = "Contact us"
    @feedback = Feedback.new
  end

  def vendor_signup
    @title = "Shop signup"
    @feedback = Feedback.new
  end

  def create
    @feedback = Feedback.new(params[:feedback])
    if @feedback.save
      redirect_to contact_us_path, notice: "Thanks for your comment!" 
    else
      render action: :new
    end
  end

  def set_feedback_active_section
    @active_section = "contact"
  end

end
