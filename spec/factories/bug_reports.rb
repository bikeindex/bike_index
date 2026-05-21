FactoryBot.define do
  factory :bug_report do
    from_address { "reporter@example.com" }
    from_name { "Reporter" }
    subject { "Something broke" }
    body { "Steps to reproduce..." }
    received_at { Time.current }
  end
end
