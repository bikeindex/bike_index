FactoryBot.define do
  factory :location do
    sequence(:name) { |n| "Location #{n}" }
    organization { FactoryBot.create(:organization) }
    country { FactoryBot.create(:country) }
    state { FactoryBot.create(:state) }
    zipcode { "60647" }
    city { "Chicago" }
    street { "foo address" }
    latitude { 41.9282162 }
    longitude { -87.6327552 }

    factory :location_chicago do
      sequence(:street) { |n| "#{n} W Jackson Blvd." }
      city { "Chicago" }
      state { State.find_or_create_by(name: "Illinois", abbreviation: "IL") }
      zipcode { "60647" }
      country { Country.united_states }
      latitude { 41.9282162 }
      longitude { -87.6327552 }
    end

    factory :location_new_york do
      sequence(:street) { |n| "#{n} Madison Ave." }
      city { "New York" }
      state { State.find_or_create_by(name: "New York", abbreviation: "NY") }
      zipcode { "10011" }
      country { Country.united_states }
      latitude { 40.7143528 }
      longitude { -74.0059731 }
    end
  end
end
