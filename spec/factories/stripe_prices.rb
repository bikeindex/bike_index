FactoryBot.define do
  factory :stripe_price do
    membership_kind { "basic" }
    interval { "monthly" }
    currency { Currency.default }
    amount_cents { 499 }
    active { true }
    sequence(:stripe_id) { |n| "price_#{n}5p2m0T0GBfX0vhLrGLAAi" }

    trait :test_stripe_id do
      initialize_with do
        StripePrice.find_by(stripe_id: stripe_id) || StripePrice.new(attributes)
      end
    end

    factory :stripe_price_basic, traits: [:test_stripe_id] do
      stripe_id { "price_0Qs5p2m0T0GBfX0vhLrGLAAi" }
    end

    factory :stripe_price_basic_yearly, traits: [:test_stripe_id] do
      stripe_id { "price_0Qs5rim0T0GBfX0vE7Q7cyoG" }
    end

    factory :stripe_price_plus, traits: [:test_stripe_id] do
      stripe_id { "price_0Qs5s1m0T0GBfX0visCJi4lq" }
    end

    factory :stripe_price_patron, traits: [:test_stripe_id] do
      stripe_id { "price_0Qs5t7m0T0GBfX0vnALQrD8t" }
    end
  end
end
