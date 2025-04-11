FactoryBot.define do
  factory :state do
    sequence(:name) { |n| "State #{n}" }
    sequence(:abbreviation) { |n| "state-#{n}" }
    country { Country.united_states }

    trait :find_or_create do
      initialize_with do
        State.find_by(abbreviation:) || State.new(attributes)
      end
    end

    factory :state_new_york, traits: [:find_or_create] do
      abbreviation { "NY" }
      country { Country.united_states }
      name { "New York" }
    end

    factory :state_illinois, traits: [:find_or_create] do
      abbreviation { "IL" }
      country { Country.united_states }
      name { "Illinois" }
    end

    factory :state_california, traits: [:find_or_create] do
      abbreviation { "CA" }
      country { Country.united_states }
      name { "California" }
    end

    factory :state_alberta, traits: [:find_or_create] do
      abbreviation { "AB" }
      country { Country.canada }
      name { "Alberta" }
    end

    factory :state_british_columbia, traits: [:find_or_create] do
      abbreviation { "BC" }
      country { Country.canada }
      name { "British Columbia" }
    end
  end
end
