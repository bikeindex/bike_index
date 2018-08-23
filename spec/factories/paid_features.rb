FactoryGirl.define do
  factory :paid_feature do
    sequence(:name) { |n| "Organization #{n}" }
  end
end
