FactoryBot.define do
  factory :membership do
    user { FactoryBot.create(:user_confirmed) }
    kind { "basic" }
    start_at { Time.current - 1.hour }
  end
end
