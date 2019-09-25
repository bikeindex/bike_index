FactoryBot.define do
  factory :stolen_record do
    bike { FactoryBot.create(:bike, stolen: true) }
    date_stolen { Time.current }

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

    trait :in_los_angeles do
      city { "Los Angeles" }
      state { State.find_or_create_by(FactoryBot.attributes_for(:state_california)) }
      country { Country.united_states }
    end

    trait :in_nyc do
      city { "New York" }
      state { State.find_or_create_by(FactoryBot.attributes_for(:state_new_york)) }
      country { Country.united_states }
    end

    trait :in_amsterdam do
      city { "Amsterdam" }
      state { nil }
      country { Country.find_or_create_by(FactoryBot.attributes_for(:country_nl)) }
    end
  end
end
