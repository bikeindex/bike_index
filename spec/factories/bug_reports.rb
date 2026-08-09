FactoryBot.define do
  factory :bug_report do
    sequence(:email) { |n| "bug-reporter-#{n}@example.com" }
    receiver { "contact@bikeindex.org" }
    subject { "Something is broken" }
    body { "Steps to reproduce: ..." }
  end
end
