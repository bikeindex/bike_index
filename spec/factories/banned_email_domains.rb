FactoryBot.define do
  factory :banned_email_domain do
    creator { FactoryBot.create(:admin) }
    sequence(:domain) { |n| "@fakedomain-#{n}.com" }
  end
end
