FactoryBot.define do
  factory :item_sale do
    amount_cents { 1 }
    currency_enum { 1 }
    item { nil }
    seller { nil }
    sold_via { 1 }
    sold_at { "2025-11-04 18:07:11" }
    ownership { nil }
  end
end
