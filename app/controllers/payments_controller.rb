=begin
*****************************************************************
* File: app/controllers/payments_controller.rb 
* Name: Class PaymentsController 
* Set some methods to deal with payments
*****************************************************************
=end

class PaymentsController < ApplicationController

=begin
  Name: revised_layout_if_enabled
  Explication: method used to enable layout  
  Params: none 
  Return: revised_layout_enabled? ? 'application_revised' : 'application_updated'
=end  
  def revised_layout_if_enabled
    revised_layout_enabled? ? 'application_revised' : 'application_updated'
  end

=begin
  Name: new 
  Explication: method used to render layout   
  Params: none
  Return: render layout: revised_layout_if_enabled 
=end
  def new
    render layout: revised_layout_if_enabled
  end

=begin
  Name: create
  Explication: method used to verify if the user is present, case yes create the bill to payments  
  Params: stripe amount, stripe subscription, stripe email, stripe token, stripe id, email, card, stripe plan 
  Return: save customer or email or user update attributes or customer save
=end
  def create
    @amount = params[:stripe_amount]
    # method assert used to debug, checking if the condition is always true for the program to continue running.
    assert_object_is_not_null(@amount)
    @subscription = params[:stripe_subscription]
    assert_object_is_not_null(@subscription)
    # Policies for user registration and thus verify possible forms of payment. 
    if params[:stripe_subscription].present?
      user = current_user || User.fuzzy_email_find(params[:stripe_email])
      email = params[:stripe_email].strip.downcase
    else
      #nothing to do
    end    
    if user.present? && user.stripe_id.present?
      customer = Stripe::Customer.retrieve(user.stripe_id)
      customer.card = params[:stripe_token]
      customer.save
    else
      #nothing to do
    end  
    if user.present?
      customer = Stripe::Customer.create(
        email: email,
        card: params[:stripe_token]
      )
      user.update_attribute :stripe_id, customer.id
    else
      customer = Stripe::Customer.all.detect { |c| c[:email].match(email).present? }
      if customer.present?
        customer.card = params[:stripe_token]
        customer.save
      else
        customer = Stripe::Customer.create(email: email, card: params[:stripe_token])
      end
    end
    @customer_id = customer.id
    if @subscription
      charge = customer.subscriptions.create(plan: params[:stripe_plan])
      charge_time = charge.current_period_start
    else
      # create the categories to attributes in stripe
      charge = Stripe::Charge.create(
        customer:     @customer_id,
        amount:       @amount,
        description:  'Bike Index customer',
        currency:     'usd'
      )
      charge_time = charge.created
    end
    # Create a new payment with its attributes
    payment = Payment.new(
      user_id: (user.id if user.present?),
      email: email,
      is_current: true,
      stripe_id: charge.id,
      first_payment_date: Time.at(charge_time).utc.to_datetime,
      amount: @amount)
    payment.is_recurring = true 
    if @subscription
      unless payment.save
        raise StandardError, "Unable to create a payment. #{payment.to_yaml}"
    else
      # nothing to do    
    end
    render layout: revised_layout_if_enabled
    # exception handling to check the error, if any, and display on the screen the message
    rescue Stripe::CardError => e
      flash[:error] = e.message
      redirect_to new_payment_path and return
  end

end
