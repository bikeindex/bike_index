FactoryBot.define do
  factory :organization_feature do
    kind { "standard" }
    sequence(:name) { |n| "Feature #{n}" }
    amount_cents { 1000 }
    factory :organization_feature_one_time do
      kind { "standard_one_time" }
    end
  end
end
