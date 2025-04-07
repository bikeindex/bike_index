FactoryBot.define do
  factory :marketplace_listing do
    seller { nil }
    buyer { nil }
    item { nil }
    published_at { "2025-04-06 14:57:46" }
    sold_at { "2025-04-06 14:57:46" }
    price_cents { 1 }
    willing_to_ship { false }
  end
end
