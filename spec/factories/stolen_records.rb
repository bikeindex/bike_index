FactoryBot.define do
  factory :stolen_record do
    bike { FactoryBot.create(:bike, stolen: true) }
    date_stolen { Time.current }
    skip_geocoding { true }

    factory :stolen_record_recovered do
      bike { FactoryBot.create(:bike) }
      recovered_at { Time.current }
      recovered_description { "Awesome help by Bike Index" }
      current { false }
    end

    trait :with_alert_image do
      transient do
        filename { nil }
      end

      after(:create) do |stolen_record, evaluator|
        FactoryBot.create(:alert_image,
          :with_image,
          stolen_record: stolen_record,
          filename: evaluator.filename)
      end
    end

    trait :with_bike_image do
      bike { FactoryBot.create(:bike, :with_image) }
    end
  end
end
