class PaymentsController < ApplicationController
  layout 'payments_layout'

  def new
  end

  def create
    amount = params[:stripe_amount]
    subscription = params[:stripe_subscription] if params[:stripe_subscription].present?
    user = current_user || User.fuzzy_confirmed_or_unconfirmed_email_find(params[:stripe_email])
    email = params[:stripe_email].strip.downcase
    if user.present? && user.stripe_id.present?
      customer = Stripe::Customer.retrieve(user.stripe_id)
      customer.card = params[:stripe_token]
      customer.save
    elsif user.present?
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
        customer = Stripe::Customer.create(
          email: email,
          card: params[:stripe_token]
        )
      end
    end
    @customer_id = customer.id
    if subscription
      charge = customer.subscriptions.create(plan: params[:stripe_plan])
      charge_time = charge.current_period_start
    else
      charge = Stripe::Charge.create(
        customer:     @customer_id,
        amount:       amount,
        description:  'Bike Index customer',
        currency:     'usd'
      )
      charge_time = charge.created
    end
    @payment = Payment.new(
      user_id: (user.id if user.present?),
      email: email,
      is_current: true,
      stripe_id: charge.id,
      first_payment_date: Time.at(charge_time).utc.to_datetime,
      amount: amount,
    )
    @payment.is_recurring = true if subscription
    @payment.is_payment = true if params[:is_payment]
    unless @payment.save
      raise StandardError, "Unable to create a payment. #{payment.to_yaml}"
    end
  rescue Stripe::CardError => e
    flash[:error] = e.message
    redirect_to new_payment_path and return
  end
end
