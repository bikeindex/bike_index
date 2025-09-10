FactoryBot.define do
  factory :marketplace_listing do
    buyer { nil }
    item { FactoryBot.create(:bike, :with_primary_activity) }
    seller { item&.user || FactoryBot.create(:user_confirmed) }
    amount_cents { 5_000 }
    condition { "excellent" }

    status { "draft" }

    trait :with_address_record do
      address_record { FactoryBot.build(:address_record, kind: :marketplace_listing, user: seller) }
    end

    trait :for_sale do
      with_address_record
      published_at { Time.current - 1.minute }
      status { :for_sale }
    end

    trait :sold do
      end_at { Time.current - 1.minute }
      published_at { Time.current - 1.week }
      buyer { FactoryBot.create(:user_confirmed) }
      status { :sold }
    end
  end
end
