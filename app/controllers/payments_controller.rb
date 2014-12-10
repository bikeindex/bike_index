class PaymentsController < ApplicationController
  layout 'application_updated'
  before_filter :authenticate_user!

  def new
  end

  def create
    @amount = params[:stripe_amount]

    if current_user.stripe_id.present?
      customer = Stripe::Customer.retrieve(current_user.stripe_id)
      customer.card = params[:stripe_token]
      customer.save
    else
      customer = Stripe::Customer.create(
        email: current_user.email,
        card: params[:stripe_token]
      )
      current_user.update_attribute :stripe_id, customer.id
    end
    charge = Stripe::Charge.create(
      customer:     customer.id,
      amount:       @amount,
      description:  'Bike Index customer',
      currency:     'usd'
    )
    attrs = {
      user_id: current_user.id,
      # is_current: false,
      # is_recurring: false,
      stripe_id: charge.id,
      last_payment_date: Time.now,
      first_payment_date: Time.now,
      amount: @amount
    }
    Payment.create(attrs)

  rescue Stripe::CardError => e
    flash[:error] = e.message
    redirect_to new_payment_path
  end

end
