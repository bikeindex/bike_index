FactoryBot.define do
  sequence :unique_email do |n|
    "user#{n}s@bikeiasdndex.org"
  end

  sequence :unique_name do |n|
    "Special_name#{n}"
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
    name { FactoryBot.generate(:unique_name) }
    count { 1 }
  end

  factory :rear_gear_type do
    name { FactoryBot.generate(:unique_name) }
    count { 1 }
  end

  factory :wheel_size do
    name { FactoryBot.generate(:unique_name) }
    iso_bsd { FactoryBot.generate(:unique_iso) }
    priority { 1 }
    description { FactoryBot.generate(:unique_name) }
  end

  factory :handlebar_type do
    name { FactoryBot.generate(:unique_name) }
    slug { FactoryBot.generate(:unique_name).downcase }
  end

  factory :color do
    name { FactoryBot.generate(:unique_name) }
    priority { 1 }
  end

  factory :paint do
    name { FactoryBot.generate(:unique_name) }
  end

  factory :cgroup do
    name { FactoryBot.generate(:unique_name) }
  end

  factory :ctype do
    sequence(:name) { |n| "Component type#{n}" }
    cgroup { FactoryBot.create(:cgroup) }
  end

  factory :component do
    bike { FactoryBot.create(:bike) }
    ctype { FactoryBot.create(:ctype) }
  end

  factory :exchange_rate do
    from { "USD" }
    to { 3.times.map { ("A".."Z").entries.sample }.join }
    rate { rand.truncate(2) }

    factory :exchange_rate_to_eur do
      to { "EUR" }
      rate { 0.88 }
    end
  end

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

  factory :lock_type do
    name { FactoryBot.generate(:unique_name) }
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

  factory :stolen_notification do
    sender { FactoryBot.create(:user) }
    receiver { FactoryBot.create(:user) }
    bike { FactoryBot.create(:bike) }
    message { "This is a test email." }
  end

  factory :customer_contact do
    creator { FactoryBot.create(:user) }
    bike { FactoryBot.create(:bike) }
    title { "Some title" }
    body { "some message" }
    creator_email { "something@example.com" }
    user_email { "something_else@example.com" }
    kind { :stolen_contact }

    trait :stolen_bike do
      bike { FactoryBot.create(:stolen_bike) }
    end

    factory :customer_contact_potentially_found_bike do
      creator { FactoryBot.create(:user) }
      bike { FactoryBot.create(:stolen_bike) }
      kind { :bike_possibly_found }

      transient do
        match { FactoryBot.create(:abandoned_bike) }
      end

      after(:create) do |cc, evaluator|
        info_hash = {
          "match_id" => evaluator.match.id.to_s,
          "match_type" => evaluator.match.class.to_s,
          "stolen_record_id" => cc.bike.current_stolen_record.id.to_s
        }
        cc.update(
          info_hash: info_hash,
          user_email: cc.bike.owner_email,
          creator_email: cc.creator.email,
          title: "We may have found your stolen #{cc.bike.title_string}",
          body: "Check this matching bike: #{evaluator.match.title_string}"
        )
      end
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
