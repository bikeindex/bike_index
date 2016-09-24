FactoryGirl.define do
  factory :bike_organization do
    association :bike
    association :organization
  end
end
