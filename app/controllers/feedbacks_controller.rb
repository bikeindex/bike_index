=begin
*****************************************************************
* File: app/controllers/feedbacks_controller.rb 
* Name: Class FeadBacksController 
* Set some messages given a feedback to the user
*****************************************************************
=end

class FeedbacksController < ApplicationController
  
  layout 'content'
  before_filter :set_feedback_active_section
  
  # Only logged in users will recive this feadback messages
  before_filter :authenticate_user, only: [:new, :create]
  before_filter :set_revised_layout

  # Home page of feadback messages
  def index
    @feedback = Feedback.new
  end

  # Must check if this method is call in some where
  def new
  end

  # Feadback messages about user actions 
  def create
    @feedback = Feedback.new(params[:feedback])
    if @feedback.save
      if @feedback.feedback_type == 'spokecard'
        flash[:notice] = "Thanks! We'll tell you as soon as we link your bike."
        redirect_to spokecard_path and return
      elsif @feedback.feedback_type == 'shop_submission'
        flash[:notice] = "Thanks! We'll set up the shop and give you a call."
        redirect_to where_path and return
      else
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
end
