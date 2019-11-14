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

    trait :in_los_angeles do
      latitude { 34.05223 }
      longitude { -118.24368 }
      city { "Los Angeles" }
      state { State.find_or_create_by(FactoryBot.attributes_for(:state_california)) }
      country { Country.united_states }
    end

    trait :in_nyc do
      latitude { 40.7143528 }
      longitude { -74.0059731 }
      city { "New York" }
      state { State.find_or_create_by(FactoryBot.attributes_for(:state_new_york)) }
      country { Country.united_states }
    end

    trait :in_chicago do
      latitude { 41.8624488 }
      longitude { -87.6591502 }
      city { "Chicago" }
      state { State.find_or_create_by(FactoryBot.attributes_for(:state_illinois)) }
      country { Country.united_states }
    end

    trait :in_amsterdam do
      latitude { 52.37403 }
      longitude { 4.88969 }
      city { "Amsterdam" }
      state { nil }
      country { Country.netherlands }
    end
  end
end
