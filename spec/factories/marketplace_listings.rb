FactoryBot.define do
  factory :marketplace_listing do
    seller { FactoryBot.create(:user) }
    buyer { nil }
    item { FactoryBot.create(:bike) }
    for_sale_at { Time.current - 1.day }
    sold_at { nil }
    price_cents { 5_000 }
    willing_to_ship { false }
  end
end
