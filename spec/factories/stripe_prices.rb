FactoryBot.define do
  factory :stripe_price do
    membership_kind { 1 }
    interval { 1 }
    currency { Currency.default }
  end
end
