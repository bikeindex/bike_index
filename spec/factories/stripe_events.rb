FactoryBot.define do
  factory :stripe_event do
    stripe_subscription { nil }
    name { "MyString" }
  end
end
