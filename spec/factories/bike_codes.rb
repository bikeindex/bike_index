FactoryGirl.define do
  factory :bike_code do
    sequence(:code) { |n| "999#{n}" }
  end
end
