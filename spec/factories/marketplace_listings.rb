FactoryBot.define do
  factory :marketplace_listing do
    seller { FactoryBot.create(:user_confirmed) }
    buyer { nil }
    item { FactoryBot.create(:bike) }
    amount_cents { 5_000 }

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
