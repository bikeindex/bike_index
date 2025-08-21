# == Schema Information
#
# Table name: locations
#
#  id                       :integer          not null, primary key
#  city                     :string(255)
#  default_impound_location :boolean          default(FALSE)
#  deleted_at               :datetime
#  email                    :string(255)
#  impound_location         :boolean          default(FALSE)
#  latitude                 :float
#  longitude                :float
#  name                     :string(255)
#  neighborhood             :string
#  not_publicly_visible     :boolean          default(FALSE)
#  phone                    :string(255)
#  shown                    :boolean          default(FALSE)
#  street                   :string(255)
#  zipcode                  :string(255)
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  country_id               :integer
#  organization_id          :integer
#  state_id                 :integer
#
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

    factory :location_chicago do
      sequence(:street) { |n| "#{n} W Jackson Blvd." }
      city { "Chicago" }
      state { State.find_or_create_by(name: "Illinois", abbreviation: "IL", country: Country.united_states) }
      zipcode { "60647" }
      country { Country.united_states }
      latitude { 41.9282162 }
      longitude { -87.6327552 }
    end

    factory :location_nyc do
      sequence(:street) { |n| "#{n} Madison Ave." }
      city { "New York" }
      state { State.find_or_create_by(name: "New York", abbreviation: "NY", country: Country.united_states) }
      zipcode { "10011" }
      country { Country.united_states }
      latitude { 40.7143528 }
      longitude { -74.0059731 }
    end

    factory :location_los_angeles do
      sequence(:street) { |n| "#{n} Manzanita Ave." }
      city { "Los Angeles" }
      state { State.find_or_create_by(name: "California", abbreviation: "CA", country: Country.united_states) }
      zipcode { "90021" }
      country { Country.united_states }
      latitude { 34.05223 }
      longitude { -118.24368 }
    end

    factory :location_edmonton, traits: [:in_edmonton]
  end
end
