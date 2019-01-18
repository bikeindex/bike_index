FactoryGirl.define do
  factory :user_email do
    user { FactoryGirl.create(:user_confirmed) }
    email { generate(:unique_email) }
  end
end
