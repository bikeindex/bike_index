FactoryGirl.define do
  factory :ownership do
    association :bike, factory: :bike
    association :creator, factory: :confirmed_user
    current true
    sequence(:owner_email) { |n| "owner#{n}@example.com" }
    factory :organization_ownership do
      association :bike, factory: :creation_organization_bike
    end
  end
end
