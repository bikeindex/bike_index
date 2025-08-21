# == Schema Information
#
# Table name: stripe_prices
#
#  id               :bigint           not null, primary key
#  active           :boolean          default(FALSE)
#  amount_cents     :integer
#  currency_enum    :integer
#  interval         :integer
#  live             :boolean          default(FALSE)
#  membership_level :integer
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  stripe_id        :string
#
FactoryBot.define do
  factory :stripe_price do
    membership_level { "basic" }
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
      interval { "yearly" }
      amount_cents { 4999 }
      stripe_id { "price_0Qs5rim0T0GBfX0vE7Q7cyoG" }

      factory :stripe_price_basic_yearly_cad do
        currency_enum { "cad" }
        stripe_id { "price_0Qs61bm0T0GBfX0vjadfNRv8" }
      end

      factory :stripe_price_basic_archived do
        amount_cents { 5999 }
        active { false }
        stripe_id { "price_0R1BSzm0T0GBfX0vHXryVB6y" }
      end
    end

    factory :stripe_price_plus, traits: [:test_stripe_id] do
      membership_level { "plus" }
      amount_cents { 999 }
      stripe_id { "price_0Qs5s1m0T0GBfX0visCJi4lq" }
    end

    factory :stripe_price_patron, traits: [:test_stripe_id] do
      membership_level { "patron" }
      amount_cents { 4999 }
      stripe_id { "price_0Qs5t7m0T0GBfX0vnALQrD8t" }
    end
  end
end
