FactoryBot.define do
  factory :user_registration_organization do
    user { FactoryBot.create(:user_confirmed) }
    organization { FactoryBot.create(:organization) }
    all_bikes { organization.user_registration_all_bikes? }
  end
end
