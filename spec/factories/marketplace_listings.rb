FactoryBot.define do
  factory :marketplace_listing do
    seller { FactoryBot.create(:user_confirmed) }
    buyer { nil }
    item { FactoryBot.create(:bike) }
    price_cents { 5_000 }
    willing_to_ship { false }

    trait :for_sale do
      for_sale_at { Time.current - 1.minute }
    end

    trait :sold do
      sold_at { Time.current - 1.minute }
      buyer { FactoryBot.create(:user_confirmed) }
    end
  end
end
