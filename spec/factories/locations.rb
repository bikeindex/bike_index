FactoryBot.define do
  factory :location do
    sequence(:name) { |n| "Location #{n}" }
    organization { FactoryBot.create(:organization) }
    country { FactoryBot.create(:country) }
    state { FactoryBot.create(:state) }
    zipcode { "60647" }
    city { "Chicago" }
    street { "foo address" }
    skip_geocoding { true }
    latitude { 41.9282162 }
    longitude { -87.6327552 }

    after(:create) do |location|
      # Save to simulate after_commit callback
      location.organization.save
    end

    trait :regional_organization do
      organization { FactoryBot.create(:organization_with_regional_bike_counts) }
    end

    trait :with_virtual_line_on do
      organization { FactoryBot.create(:organization_with_paid_features, :in_nyc, enabled_feature_slugs: ["virtual_line"]) }
      after(:create) do |location, _evaluator|
        FactoryBot.create(:appointment_configuration,
                          location: location,
                          organization: location.organization,
                          virtual_line_on: true)
      end
    end

    factory :location_chicago do
      sequence(:street) { |n| "#{n} W Jackson Blvd." }
      city { "Chicago" }
      state { State.find_or_create_by(name: "Illinois", abbreviation: "IL") }
      zipcode { "60647" }
      country { Country.united_states }
      latitude { 41.9282162 }
      longitude { -87.6327552 }
    end

    factory :location_nyc do
      sequence(:street) { |n| "#{n} Madison Ave." }
      city { "New York" }
      state { State.find_or_create_by(name: "New York", abbreviation: "NY") }
      zipcode { "10011" }
      country { Country.united_states }
      latitude { 40.7143528 }
      longitude { -74.0059731 }
    end

    factory :location_los_angeles do
      sequence(:street) { |n| "#{n} Manzanita Ave." }
      city { "Los Angeles" }
      state { State.find_or_create_by(name: "California", abbreviation: "CA") }
      zipcode { "90021" }
      country { Country.united_states }
      latitude { 34.05223 }
      longitude { -118.24368 }
    end

    factory :location_edmonton, traits: [:in_edmonton]
  end
end
