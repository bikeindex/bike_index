FactoryBot.define do
  factory :state do
    sequence(:name) { |n| "State #{n}" }
    sequence(:abbreviation) { |n| "state-#{n}" }
    country { Country.united_states }

    factory :state_new_york do
      abbreviation { "NY" }
      country { Country.united_states }
      name { "New York" }
    end

    factory :state_illinois do
      abbreviation { "IL" }
      country { Country.united_states }
      name { "Illinois" }
    end

    factory :state_california do
      abbreviation { "CA" }
      country { Country.united_states }
      name { "California" }
    end
  end
end
