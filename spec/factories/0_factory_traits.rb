# named 0_factories so it's loaded first, since it has
FactoryBot.define do
  sequence :unique_email do |n|
    "user#{n}s@bikeindex.org"
  end

  sequence :serial_number do |n|
    "serial#{n}"
  end

  sequence :name do |n|
    "Mike #{n}ison"
  end

  sequence :slug do |n|
    "bike-shop-#{n}"
  end

  sequence :unique_iso do |n|
    "#{n}0"
  end

  # Location traits
  trait :in_amsterdam do
    latitude { 52.37403 }
    longitude { 4.88969 }
    city { "Amsterdam" }
    state_id { nil }
    country_id { Country.netherlands.id }
    street { "Spuistraat 134afd.Gesch." }
    zipcode { "1012" }
  end

  trait :in_chicago do
    latitude { 41.8624488 }
    longitude { -87.6591502 }
    city { "Chicago" }
    state_id { FactoryBot.create(:state_illinois).id }
    country_id { Country.united_states.id }
    street { "1300 W 14th Pl" }
    zipcode { "60608" }
  end

  trait :in_los_angeles do
    latitude { 34.05223 }
    longitude { -118.24368 }
    street { "100 W 1st St" }
    city { "Los Angeles" }
    state_id { FactoryBot.create(:state_california).id }
    zipcode { "90021" }
    country_id { Country.united_states.id }
  end

  trait :in_nyc do
    latitude { 40.7143528 }
    longitude { -74.0059731 }
    city { "New York" }
    state_id { FactoryBot.create(:state_new_york).id }
    country_id { Country.united_states.id }
    street { "278 Broadway" }
    zipcode { "10007" }
  end

  trait :in_vancouver do
    latitude { 49.253992 }
    longitude { -123.241084 }
    street { "278 Broadway" }
    zipcode { "10007" }
    city { "Vancouver" }
    state_id { nil }
    country_id { Country.canada.id }
  end

  trait :in_edmonton do
    latitude { 53.5069377 }
    longitude { -113.5508765 }
    street { "9330 Groat Rd NW" }
    zipcode { "AB T6G 2B3" }
    city { "Edmonton" }
    state_id { nil }
    country_id { Country.canada.id }
  end

  # address record location traits
  trait :address_in_amsterdam do
    with_address_record

    address_record { FactoryBot.create(:address_record, :amsterdam, kind: address_record_kind) }
  end

  trait :address_in_chicago do
    with_address_record

    address_record { FactoryBot.create(:address_record, :chicago, kind: address_record_kind) }
  end

  trait :address_in_los_angeles do
    with_address_record

    address_record { FactoryBot.create(:address_record, :los_angeles, kind: address_record_kind) }
  end

  trait :address_in_nyc do
    with_address_record

    address_record { FactoryBot.create(:address_record, :nyc, kind: address_record_kind) }
  end

  trait :address_in_vancouver do
    with_address_record

    address_record { FactoryBot.create(:address_record, :vancouver, kind: address_record_kind) }
  end

  trait :address_in_edmonton do
    with_address_record

    address_record { FactoryBot.create(:address_record, :edmonton, kind: address_record_kind) }
  end
end
