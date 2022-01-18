FactoryBot.define do
  sequence :unique_email do |n|
    "user#{n}s@bikeiasdndex.org"
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

  factory :front_gear_type do
    sequence(:name) { |n| "Front Gear #{n}" }
    count { 1 }
  end

  factory :rear_gear_type do
    sequence(:name) { |n| "Rear Gear #{n}" }
    count { 1 }
  end

  factory :wheel_size do
    sequence(:name) { |n| "Wheel size #{n}" }
    iso_bsd { FactoryBot.generate(:unique_iso) }
    priority { 1 }
    sequence(:description) { |n| "Wheel Description #{n}" }
  end

  factory :paint do
    sequence(:name) { |n| "Paint #{n}" }
  end

  factory :cgroup do
    sequence(:name) { |n| "Cgroup #{n}" }
  end

  factory :ctype do
    sequence(:name) { |n| "Component type#{n}" }
    cgroup { FactoryBot.create(:cgroup) }
  end

  factory :component do
    bike { FactoryBot.create(:bike) }
    ctype { FactoryBot.create(:ctype) }
  end

  factory :lock_type do
    sequence(:name) { |n| "Lock type #{n}" }
  end

  factory :lock do
    user { FactoryBot.create(:user) }
    manufacturer { FactoryBot.create(:manufacturer) }
    lock_type { FactoryBot.create(:lock_type) }
  end

  factory :integration do
    access_token { "12345teststststs" }
  end

  factory :blog do
    user { FactoryBot.create(:user) }
    body { "Some sweet blog content that everyone loves" }
    sequence(:title) { |n| "Blog title #{n}" }

    trait :published do
      published { true }
    end

    trait :dutch do
      language { "nl" }
    end
  end

  # Location traits
  trait :in_amsterdam do
    latitude { 52.37403 }
    longitude { 4.88969 }
    city { "Amsterdam" }
    state { nil }
    country { Country.netherlands }
    street { "Spuistraat 134afd.Gesch." }
    zipcode { "1012" }
  end

  trait :in_chicago do
    latitude { 41.8624488 }
    longitude { -87.6591502 }
    city { "Chicago" }
    state { State.find_or_create_by(FactoryBot.attributes_for(:state_illinois)) }
    country { Country.united_states }
    street { "1300 W 14th Pl" }
    zipcode { "60608" }
  end

  trait :in_los_angeles do
    latitude { 34.05223 }
    longitude { -118.24368 }
    street { "100 W 1st St" }
    city { "Los Angeles" }
    state { State.find_or_create_by(FactoryBot.attributes_for(:state_california)) }
    zipcode { "90021" }
    country { Country.united_states }
  end

  trait :in_nyc do
    latitude { 40.7143528 }
    longitude { -74.0059731 }
    city { "New York" }
    state { State.find_or_create_by(FactoryBot.attributes_for(:state_new_york)) }
    country { Country.united_states }
    street { "278 Broadway" }
    zipcode { "10007" }
  end

  trait :in_vancouver do
    latitude { 49.253992 }
    longitude { -123.241084 }
    street { "278 Broadway" }
    zipcode { "10007" }
    city { "Vancouver" }
    state
    country { Country.canada }
  end

  trait :in_edmonton do
    latitude { 53.5069377 }
    longitude { -113.5508765 }
    street { "9330 Groat Rd NW" }
    zipcode { "AB T6G 2B3" }
    city { "Edmonton" }
    state
    country { Country.canada }
  end
end
