class PaymentsController < ApplicationController
  layout "payments_layout"

  def new
  end

  def success
    @payment = if params[:payment_id].present?
      Payment.where(id: params[:payment_id], user_id: current_user&.id).first
    else
      nil
    end
  end

  def create
    @payment = Payment.new(permitted_create_parameters)
    stripe_session = Stripe::Checkout::Session.create({
      submit_type: @payment.donation? ? "Donate" : "Pay",
      payment_method_types: ["card"],
      line_items: [{
        price: @payment.amount_cents
        quantity: 1
        currency: @payment.currency
      #   price_data: {
      #     unit_amount: params[:stripe_amount],
      #     currency: "usd",
      #     product_data: {
      #       name: "Stubborn Attachments",
      #       images: ["https://i.imgur.com/EHyR2nP.png"],
      #     },
      #   },
      #   quantity: 1,
      # }],
      mode: "payment",
      success_url: "#{ENV['BASE_URL']}/payments/success?session_id={CHECKOUT_SESSION_ID}",
      cancel_url: new_payment_url,
    })

    pp stripe_session

    # redirect stripe_session.url, 303
  end

  def legacy_create
    amount_cents = params[:stripe_amount]
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
    if subscription
      charge = customer.subscriptions.create(plan: params[:stripe_plan])
      charge_time = charge.current_period_start
    else
      charge = Stripe::Charge.create(
        customer: customer.id,
        amount: amount_cents,
        description: "Bike Index customer",
        currency: "usd"
      )
      charge_time = charge.created
    end
    @payment = Payment.new(
      user_id: (user.id if user.present?),
      email: email,
      is_current: true,
      stripe_id: charge.id,
      first_payment_date: Time.at(charge_time).utc.to_datetime,
      amount_cents: amount_cents
    )
    @payment.is_recurring = true if subscription
    @payment.kind = "payment" if ParamsNormalizer.boolean(params[:is_payment])
    unless @payment.save
      raise StandardError, "Unable to create a payment. #{payment.to_yaml}"
    end
  rescue Stripe::CardError => e
    flash[:error] = e.message
    redirect_to(new_payment_path) && return
  end

  private

  def permitted_create_parameters
    params.require(:payment)
      .permit(:kind, :amount_cents, :email, :currency)
  end
end
