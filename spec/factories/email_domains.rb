FactoryBot.define do
  factory :email_domain do
    creator { FactoryBot.create(:superuser) }
    sequence(:domain) { |n| "@fakedomain-#{n}.com" }
  end
end
