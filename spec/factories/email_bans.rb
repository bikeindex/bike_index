FactoryBot.define do
  factory :email_ban do
    user { FactoryBot.create(:user_confirmed) }
    start_at { 1.day.ago }
    end_at { nil }
    reason { :email_domain }
  end
end
