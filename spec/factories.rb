FactoryGirl.define do
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

  factory :cycle_type do
    name { FactoryGirl.generate(:unique_name) }
    slug { FactoryGirl.generate(:unique_name) }
  end

  factory :manufacturer do
    name { FactoryGirl.generate(:unique_name) }
    frame_maker true
  end

  factory :frame_material do
    name { FactoryGirl.generate(:unique_name) }
    slug { FactoryGirl.generate(:unique_name) }
  end

  factory :propulsion_type do
    name { FactoryGirl.generate(:unique_name) }
  end

  factory :front_gear_type do
    name { FactoryGirl.generate(:unique_name) }
    count 1
  end

  factory :rear_gear_type do
    name { FactoryGirl.generate(:unique_name) }
    count 1
  end

  factory :wheel_size do
    name { FactoryGirl.generate(:unique_name) }
    iso_bsd { FactoryGirl.generate(:unique_iso) }
    priority 1
    description { FactoryGirl.generate(:unique_name) }
  end

  factory :handlebar_type do
    name { FactoryGirl.generate(:unique_name) }
    slug { FactoryGirl.generate(:unique_name).downcase }
  end

  factory :color do
    name { FactoryGirl.generate(:unique_name) }
    priority 1
  end

  factory :paint do
    name { FactoryGirl.generate(:unique_name) }
  end

  factory :payment do
    association :user
    amount '999'
  end

  factory :cgroup do
    name { FactoryGirl.generate(:unique_name) }
  end

  factory :ctype do
    sequence(:name) { |n| "Component type#{n}" }
    association :cgroup
  end

  factory :ownership do
    association :bike, factory: :bike
    association :creator, factory: :confirmed_user
    current true
    sequence(:owner_email) { |n| "owner#{n}@example.com" }
    factory :organization_ownership do
      association :bike, factory: :creation_organization_bike
    end
  end

  factory :component do
    association :bike, factory: :bike
    association :ctype
  end

  factory :location do
    name
    association :organization
    association :country
    association :state
    zipcode '60647'
    city 'Chicago'
    street 'foo address'
  end

  factory :country do
    name
    sequence(:iso) { |n| "D#{n}" }
  end

  factory :state do
    name
    association :country
    sequence(:abbreviation) { |n| "Q#{n}" }
  end

  factory :lock_type do
    name { FactoryGirl.generate(:unique_name) }
  end

  factory :lock do
    association :user
    association :manufacturer
    association :lock_type
  end

  factory :organization_invitation do
    association :inviter, factory: :user
    association :organization
    invitee_email 'mike@test.com'
  end

  factory :membership do
    role 'member'
    factory :existing_membership do
      association :user
      association :organization
    end
  end

  factory :integration do
    access_token '12345teststststs'
  end

  factory :public_image do |u|
    u.image { File.open(File.join(Rails.root, 'spec', 'fixtures', 'bike.jpg')) }
    association :imageable, factory: :bike
  end

  factory :blog do
    user
    body 'Some sweet blog content that everyone loves'
    sequence(:title) { |n| "Blog title #{n}" }
  end

  factory :feedback do
    email 'foo@boy.com'
    body 'This is a test email.'
    title 'New Feedback Submitted'
    name 'Bobby Joe'
  end

  factory :stolen_notification do
    association :sender, factory: :user
    association :receiver, factory: :user
    association :bike
    message 'This is a test email.'
  end

  factory :stolen_record do
    bike
    date_stolen Time.now
  end

  factory :customer_contact do
    association :creator, factory: :user
    association :bike
    title 'Some title'
    body 'some message'
    creator_email 'something@example.com'
    user_email 'something_else@example.com'
    contact_type 'stolen_message'
  end
end
