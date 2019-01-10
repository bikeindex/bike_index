FactoryGirl.define do
  factory :user_email do
    association :user, factory: :user_confirmed
    email { generate(:unique_email) }
  end
end
