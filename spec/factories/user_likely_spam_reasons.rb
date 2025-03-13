FactoryBot.define do
  factory :user_likely_spam_reason do
    user { FactoryBot.create(:user_confirmed) }
    reason { "email_domain" }
  end
end
