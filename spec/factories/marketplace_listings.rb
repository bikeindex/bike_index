FactoryBot.define do
  factory :marketplace_listing do
    buyer { nil }
    item { FactoryBot.create(:bike, :with_primary_activity, :with_ownership_claimed) }
    seller { item&.user || FactoryBot.create(:user_confirmed) }
    amount_cents { 5_000 }
    condition { "excellent" }

    status { "draft" }

    latitude { address_record&.latitude }
    longitude { address_record&.longitude }

    trait :with_address_record do
      transient do
        address_in { :new_york }
      end

      address_record do
        FactoryBot.build(:address_record, address_in, kind: :marketplace_listing, bike: item, user: seller)
      end
    end

    trait :for_sale do
      with_address_record

      published_at { Time.current - 1.minute }
      status { :for_sale }
    end

    trait :sold do
      end_at { Time.current - 5.minutes }
      published_at { Time.current - 1.week }
      buyer { FactoryBot.create(:user_confirmed) }
      status { :sold }
    end
  end
end
