FactoryBot.define do
  factory :user_email do
    user { FactoryBot.create(:user_confirmed) }
    email { generate(:unique_email) }
  end
end
