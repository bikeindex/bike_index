=begin
*****************************************************************
* File: app/controllers/feedbacks_controller.rb 
* Name: Class FeadBacksController 
* Set some messages given a feedback to the user
*****************************************************************
=end

class FeedbacksController < ApplicationController
  
  layout 'content'
  before_filter :set_feedback_activeSection
  
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


=begin
  Explication: create the new feedback with some conditions. 
  Feadback messages about user actions
  Paramts: patams of feedback
  Return: the new feedback
=end
  def create
    @feedback = Feedback.new(params[:feedback])
    assert_object_is_not_null(@feedback)
    if @feedback.save
      create_condition
      redirect_to about_path, notice: 'Thanks for your comment!'
    else
      if @feedback.feedback_type == 'shop_submission'
        render action: :vendor_signup
      else
        render action: :new
      end
    end
  end

=begin
  Name: create_condition
  Explication: condition to simplify the create method
  Params: feedback type
  Return: result of conditions
=end 
  def create_condition
    if @feedback.feedback_type == 'spoke_card'
        flash[:notice] = "Thanks! We'll tell you as soon as we link your bike."
        redirect_to spoke_card_path and return
      elsif @feedback.feedback_type == 'shop_submission'
        flash[:notice] = "Thanks! We'll set up the shop and give you a call."
        redirect_to where_path and return
      else
      end
  end


  # Name: set_feedback_activeSection
  # Return: @activeSection

  def set_feedback_activeSection
    @activeSection = 'contact'
  end
end
