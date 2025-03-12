FactoryBot.define do
  factory :email_domain do
    creator { FactoryBot.create(:admin) }
    sequence(:domain) { |n| "@fakedomain-#{n}.com" }
  end
end
