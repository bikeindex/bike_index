FactoryBot.define do
  factory :marketplace_listing do
    buyer { nil }
    item { FactoryBot.create(:bike) }
    seller { item&.user || FactoryBot.create(:user_confirmed) }
    amount_cents { 5_000 }
    condition { "excellent" }

    status { "draft" }

    trait :for_sale do
      published_at { Time.current - 1.minute }
      status { :for_sale }
    end

    trait :sold do
      end_at { Time.current - 1.minute }
      buyer { FactoryBot.create(:user_confirmed) }
      status { :sold }
    end

    trait :with_address_record do
      address_record { FactoryBot.build(:address_record, kind: :marketplace_listing, user: seller) }
    end
  end
end
