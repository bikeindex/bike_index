FactoryBot.define do
  factory :address_record do
    davis
    skip_geocoding { true }

    trait :davis do
      city { "Davis" }
      region_record { FactoryBot.create(:state_california) }
      country { Country.united_states }
      postal_code { "95616" }
      street { "One Shields Ave" }
      latitude { 38.5449065 }
      longitude { -121.7405167 }
    end

    trait :amsterdam do
      latitude { 52.37403 }
      longitude { 4.88969 }
      city { "Amsterdam" }
      region_string { "North Holland" }
      region_record { nil }
      country { Country.netherlands }
      street { "Spuistraat 134afd.Gesch." }
      postal_code { "1012" }
    end

    trait :chicago do
      latitude { 41.8624488 }
      longitude { -87.6591502 }
      city { "Chicago" }
      region_record { FactoryBot.create(:state_illinois) }
      country { Country.united_states }
      street { "1300 W 14th Pl" }
      postal_code { "60608" }
    end

    trait :los_angeles do
      latitude { 34.05223 }
      longitude { -118.24368 }
      street { "100 W 1st St" }
      city { "Los Angeles" }
      region_record { FactoryBot.create(:state_california) }
      postal_code { "90021" }
      country { Country.united_states }
    end

    # geocoder default
    trait :new_york do
      latitude { 40.7143528 }
      longitude { -74.0059731 }
      city { "New York" }
      region_record { FactoryBot.create(:state_new_york) }
      country { Country.united_states }
      street { "278 Broadway" }
      postal_code { "10007" }
    end

    trait :vancouver do
      latitude { 49.253992 }
      longitude { -123.241084 }
      street { "278 W Broadway" }
      postal_code { "V5Y 1P5" }
      city { "Vancouver" }
      region_record { FactoryBot.create(:state_british_columbia) }
      country { Country.canada }
    end

    trait :edmonton do
      latitude { 53.5069377 }
      longitude { -113.5508765 }
      street { "9330 Groat Rd NW" }
      postal_code { "AB T6G 2B3" }
      city { "Edmonton" }
      region_record { FactoryBot.create(:state_alberta) }
      country { Country.canada }
    end
  end
end
