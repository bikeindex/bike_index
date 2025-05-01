FactoryBot.define do
  factory :marketplace_listing do
    buyer { nil }
    item { FactoryBot.create(:bike) }
    seller { item&.user || FactoryBot.create(:user_confirmed) }
    amount_cents { 5_000 }
    condition { "excellent" }

    # condition { MarketplaceListing.conditions.keys.first }
    status { "draft" }

    trait :for_sale do
      published_at { Time.current - 1.minute }
    end

    trait :sold do
      end_at { Time.current - 1.minute }
      buyer { FactoryBot.create(:user_confirmed) }
    end
  end
end
