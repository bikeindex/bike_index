FactoryGirl.define do
  factory :user_email do
    association :user, factory: :confirmed_user
    email { generate(:unique_email) }
  end
end
