module TheftAlertPaymentCreator
  class << self
    def create!(user:, stripe_email:, stripe_token:, stripe_amount:, stripe_currency:)
      customer = stripe_customer_find_or_create_by(
        stripe_id: user.stripe_id,
        stripe_email: stripe_email,
        stripe_token: stripe_token,
      )

      user.update(stripe_id: customer.id)

      charge = Stripe::Charge.create(
        customer: customer.id,
        amount: stripe_amount,
        description: "Bike Index Alert",
        currency: stripe_currency,
      )

      payment = Payment.new(
        payment_method: "stripe",
        user_id: user.id,
        email: customer.email,
        kind: "theft_alert",
        is_current: true,
        stripe_id: charge.id,
        first_payment_date: Time.at(charge.created).utc.to_datetime,
        amount_cents: stripe_amount,
        currency: stripe_currency,
      )

      payment.save!

      payment
    end

    private

    def stripe_customer_find_or_create_by(stripe_id:, stripe_email:, stripe_token:)
      if stripe_id.blank?
        return Stripe::Customer.create(email: stripe_email.strip.downcase, card: stripe_token)
      end

      customer = Stripe::Customer.retrieve(stripe_id)
      customer.card = stripe_token
      customer.save
    end
  end
end
