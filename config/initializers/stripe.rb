Rails.configuration.stripe = {
  publishable_key: ENV["STRIPE_PUBLISHABLE_KEY"],
  secret_key: ENV["STRIPE_SECRET_KEY"]
}

Stripe.api_key = ENV["STRIPE_SECRET_KEY"]
STRIPE_LIVE_MODE = Stripe.api_key.start_with?("sk_live_")
