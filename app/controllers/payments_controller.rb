class PaymentsController < ApplicationController
  layout "payments_layout"

  def new
  end

  def apple_verification
    render layout: false
  end

  def success
    @payment = if params[:session_id].present?
      Payment.where(stripe_id: params[:session_id]).first
    end

    # Update the stripe info
    if @payment.present? && @payment.stripe? && @payment.incomplete?
      if @payment.stripe_session.payment_status == "paid"
        @payment.update(first_payment_date: Time.current,
                        amount_cents: @payment.stripe_session.amount_total)
        # Update email if we can
        if @payment.user.blank? && @payment.stripe_customer.present?
          @payment.update(email: @payment.stripe_customer.email)
          if current_user.present? && current_user.stripe_id.blank?
            current_user.update(stripe_id: @payment.stripe_customer.id)
          end
        end
      end
    end
  end

  def create
    @payment = Payment.new(permitted_create_parameters)
    images = if @payment.donation?
      ["https://files.bikeindex.org/uploads/Pu/151203/reg_hance.jpg"]
    else
      []
    end
    stripe_session = Stripe::Checkout::Session.create(current_customer_data.merge(
      submit_type: @payment.donation? ? "donate" : "pay",
      payment_method_types: ["card"],
      line_items: [{
        price_data: {
          unit_amount: @payment.amount_cents,
          currency: @payment.currency,
          product_data: {
            name: @payment.kind,
            images: images
          }
        },
        quantity: 1
      }],
      mode: "payment",
      success_url: @payment.stripe_success_url,
      cancel_url: @payment.stripe_cancel_url
    ))

    @payment.update(stripe_id: stripe_session.id)
    redirect_to stripe_session.url
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
      .merge(user_id: current_user&.id, stripe_kind: "stripe_session")
  end
end
