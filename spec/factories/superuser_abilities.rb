FactoryBot.define do
  factory :superuser_ability do
    user { FactoryBot.create(:user_confirmed) }
  end
end
