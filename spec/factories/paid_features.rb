FactoryGirl.define do
  factory :paid_feature do
    kind "standard"
    sequence(:name) { |n| "Feature #{n}" }
    amount_cents 1000
    factory :paid_feature_one_time do
      kind "standard_one_time"
    end
  end
end
