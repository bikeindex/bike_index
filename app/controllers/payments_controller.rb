class PaymentsController < ApplicationController
  layout "payments_layout"

  def new
  end

  def success
    @payment = if params[:session_id].present?
      Payment.where(stripe_id: params[:session_id]).first
    else
      nil
    end

    if @payment.present? && @payment.stripe? && @payment.incomplete?
      if @payment.stripe_session.payment_status == "paid"
        @payment.update(first_payment_date: Time.current,
          amount_cents: @payment.stripe_session.amount_total)
        # Update email if we can
        if @payment.user.blank? && @payment.stripe_customer.present?
          @payment.update(email: @payment.stripe_customer.email)
          if current_user.stripe_id.blank?
            current_user.update(stripe_id: @payment.stripe_customer.id)
          end
        end
      end
    end
  end

  def create
    @payment = Payment.new(permitted_create_parameters)

    stripe_session = Stripe::Checkout::Session.create(current_customer_data.merge(
      submit_type: @payment.donation? ? "donate" : "pay",
      payment_method_types: ["card"],
      line_items: [{
        price_data: {
          unit_amount: @payment.amount_cents,
          currency: @payment.currency,
          product_data: {
            name: @payment.kind,
            # images: ["https://i.imgur.com/EHyR2nP.png"],
          },
        },
        quantity: 1,
      }],
      mode: "payment",
      success_url: "#{ENV['BASE_URL']}/payments/success?session_id={CHECKOUT_SESSION_ID}",
      cancel_url: new_payment_url))

    @payment.update(stripe_id: stripe_session.id)

    redirect_to stripe_session.url
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

  def current_customer_data
    return {} if current_user.blank?
    return {customer_email: current_user.email} if current_user.stripe_id.blank?
    {customer: current_user.stripe_id}
  end

  def permitted_create_parameters
    params.require(:payment)
      .permit(:kind, :amount_cents, :email, :currency)
      .merge(user_id: current_user&.id)
  end
end
