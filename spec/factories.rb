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

  factory :manufacturer do
    name { FactoryBot.generate(:unique_name) }
    frame_maker { true }
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

  factory :country do
    name
    sequence(:iso) { |n| "D#{n}" }
  end

  factory :state do
    name
    country { FactoryBot.create(:country) }
    sequence(:abbreviation) { |n| "Q#{n}" }
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
    user
    body { "Some sweet blog content that everyone loves" }
    sequence(:title) { |n| "Blog title #{n}" }
  end

  factory :feedback do
    email { "foo@boy.com" }
    body { "This is a test email." }
    title { "New Feedback Submitted" }
    name { "Bobby Joe" }
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
    contact_type { "stolen_message" }
  end
end
