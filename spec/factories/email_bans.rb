FactoryBot.define do
  factory :email_ban do
    user { FactoryBot.create(:user_confirmed) }
    start_at { Time.current - 1.day }
    end_at { nil }
    reason { :email_domain }
  end
end
